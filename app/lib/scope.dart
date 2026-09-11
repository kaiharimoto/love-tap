// The one object graph: spine, transport, sync, identity, clock. Regions read it from the
// widget tree; modules write through it. Nothing else holds state that could drift.
import 'dart:async';


import 'package:flutter/widgets.dart';

import 'ambient/ambient.dart';
import 'feelings/registry.dart';
import 'feelings/sensation.dart';
import 'flags.dart';
import 'spine/projections/state.dart';
import 'spine/projections/thread.dart';
import 'spine/spine.dart';
import 'transport/sync.dart';
import 'transport/transport.dart';

/// Time source: the wall clock, or the frozen/driven clock in capture and seeded runs.
class Clock {
  Clock({this.frozenAt});
  final DateTime? frozenAt;
  Duration _offset = Duration.zero;

  DateTime now() => (frozenAt ?? DateTime.now()).add(_offset).toUtc();

  /// Capture mode: advance the driven clock.
  void advance(Duration d) => _offset += d;

  bool get frozen => frozenAt != null;
}

class AppScope extends ChangeNotifier {
  AppScope({
    required this.spine,
    required this.transport,
    required this.sync,
    required this.clock,
    Ambient? ambient,
    Sensation? sensation,
  })  : ambient = ambient ?? Ambient.of(),
        sensation = sensation ?? Sensation() {
    if (Flags.capture) sync.onLog = (line) => debugPrint('sync: $line');
    _sub = spine.changes.listen((_) => _refresh());
    _tsub = transport.status.listen((s) {
      link = s;
      notifyListeners();
    });
    _esub = transport.ephemeral.listen(_onEphemeral);
    link = transport.current;
    _refresh();
  }

  final Spine spine;
  final Transport transport;
  final SyncEngine sync;
  final Clock clock;

  /// The three surfaces the other person reaches without either of them opening anything.
  final Ambient ambient;

  /// The one thing that plays a feeling on this phone — the vibrator, the sound, the page. One
  /// rather than one per region: the capture report reads `sensation.last`, and a report that
  /// asks the wrong instance is a clip with no haptic annotation.
  final Sensation sensation;

  /// What the ambient surfaces were last told, for the capture report: the surfaces themselves
  /// (a standing notification, a push) cannot be photographed here, so what they were handed is
  /// recorded as what it is — what was sent, never a picture of it arriving.
  String? lastStandingLine;
  String? lastPocketFeeling;
  int? lastPocketAt;

  late ThreadState thread;
  late Map<Person, PersonState> state;
  late TransportStatus link;

  /// Partner typing, from ephemeral frames; expires on its own.
  bool partnerTyping = false;
  Timer? _typingTimer;
  StreamSubscription<SpineChange>? _sub;
  StreamSubscription<TransportStatus>? _tsub;
  StreamSubscription<Ephemeral>? _esub;

  Person get me => spine.identity.person;
  Person get partner => me.other;
  PersonState get partnerState => state[partner]!;
  PersonState get myState => state[me]!;

  String _lastStanding = '';
  String _lastArrival = '';

  /// A feeling from them, the moment it lands, so the shell can drop it on the desk.
  // The feeling, how hard it was sent, who sent it and when. The last two were not carried, and
  // the thing that landed on the desk was therefore the only drawing of a feeling anywhere in the
  // app with no name, no time and no sender on it — while the shelf row two inches above it wrote
  // all three. A coherence critic found the same feeling on the glass twice at once, labelled in
  // one place and anonymous in the other.
  final StreamController<(String, double, Person, int)> _landed =
      StreamController<(String, double, Person, int)>.broadcast();
  Stream<(String, double, Person, int)> get landed => _landed.stream;

  /// Kept between refreshes: the thread is a function of the log, but that does not mean
  /// recomputing it from the first event of the year every time somebody scrolls. Scrolling emits
  /// read markers, every one of which is a spine change, and the full projection measured at 177
  /// milliseconds over fourteen thousand events.
  late final ThreadProjector _threadProjector = ThreadProjector(me: me);

  /// Every feeling either of them has, rebuilt only when one is made or changed.
  ///
  /// It was constructed inside build() in five regions, each time from every event in the spine.
  /// Nothing about it changes unless a feeling_authored event arrives, which happens a handful of
  /// times a year.
  FeelingRegistry _feelings = FeelingRegistry(const []);
  int _authoredSeen = -1;
  FeelingRegistry get feelings => _feelings;

  void _refresh() {
    final all = spine.all;
    final authored = spine.countOf('feeling_authored');
    if (authored != _authoredSeen) {
      _feelings = FeelingRegistry(all);
      _authoredSeen = authored;
    }
    thread = _threadProjector.update(all,
        linkUp: link.state == LinkState.connected, refused: spine.refused,
        inFlight: spine.inFlight);
    state = projectState(all);
    _tellThePocket(all);
    notifyListeners();
  }

  /// Keep the ambient surfaces true. The standing line is rewritten only when it would actually
  /// read differently, so the phone is not woken to say the same thing twice; a feeling from them
  /// is played once, when it lands.
  void _tellThePocket(List<Event> all) {
    final line = standingLine(partner, partnerState, clock.now().millisecondsSinceEpoch);
    if (line != _lastStanding) {
      _lastStanding = line;
      lastStandingLine = line;
      unawaited(ambient.standing(partner, line));
    }
    for (var i = all.length - 1; i >= 0 && i > all.length - 12; i--) {
      final e = all[i];
      if (e.type != 'feeling' || e.author == me) continue;
      if (e.id == _lastArrival) break;
      _lastArrival = e.id;
      final f = _feelings.byId(e.payload['feeling_id'] as String? ?? '');
      final intensity = (e.payload['intensity'] as num?)?.toDouble() ?? 0.7;
      if (f != null) {
        lastPocketFeeling = f.id;
        lastPocketAt = clock.now().millisecondsSinceEpoch;
        unawaited(ambient.pocket(f, intensity));
        if (!_landed.isClosed) _landed.add((f.id, intensity, e.author, e.ts));
      }
      break;
    }
  }

  void _onEphemeral(Ephemeral e) {
    if (e.from == me) return;
    if (e.kind == 'typing') {
      partnerTyping = e.data['on'] == true;
      _typingTimer?.cancel();
      if (partnerTyping) {
        _typingTimer = Timer(const Duration(seconds: 6), () {
          partnerTyping = false;
          notifyListeners();
        });
      }
      notifyListeners();
    }
  }

  // ---- writing into the spine (every module and region goes through here) ------------------
  bool get _hostAssign => transport.role == TransportRole.host;

  Future<Event> emit(String type, Map<String, dynamic> payload, {DateTime? at}) =>
      spine.append(type, payload, at: at ?? clock.now(), hostAssign: _hostAssign);

  Future<void> sendTyping(bool on) async {
    try {
      await transport.sendEphemeral(Ephemeral(kind: 'typing', from: me, at: clock.now().millisecondsSinceEpoch, data: {'on': on}));
    } catch (_) {}
  }

  /// Advance my read marker to the latest accepted row, if it moved.
  Future<void> markRead() async {
    final latest = thread.latestSeq();
    if (latest == null) return;
    final mine = thread.readUpto[me] ?? 0;
    if (latest > mine) await emit('read_marker', {'upto_seq': latest});
  }

  static AppScope of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<_ScopeProvider>();
    assert(w != null, 'AppScope missing');
    return w!.scope;
  }

  /// Whose phone this is, read *without* subscribing to the scope.
  ///
  /// `of` registers a dependency on the InheritedNotifier, so every widget that calls it is marked
  /// dirty by every `notifyListeners` — and the spine notifies on every sync round. A thread row
  /// called `of` for one thing, and that thing is a constant for the life of the app: `me`. So
  /// every visible note was a listener of every round the other phone answered, and no amount of
  /// caching the row widget helped, because the framework was dirtying the row's own element
  /// rather than rebuilding it from above.
  ///
  /// Measured over the same twenty frames of the same fling: 38 rows built with nothing arriving,
  /// 595 with a message landing on each frame. In the capture, the same scene shot on its own
  /// built 135 rows over 300 frames and shot with the far phone up built 5,028.
  ///
  /// Safe because the provider is built once with one scope and `me` never changes inside it; a
  /// widget that needs anything that *does* change must still use `of`.
  static Person meOf(BuildContext context) {
    final w = context.getInheritedWidgetOfExactType<_ScopeProvider>();
    assert(w != null, 'AppScope missing');
    return w!.scope.me;
  }

  static Widget provide({required AppScope scope, required Widget child}) => _ScopeProvider(scope: scope, child: child);

  @override
  void dispose() {
    _sub?.cancel();
    _tsub?.cancel();
    _esub?.cancel();
    _typingTimer?.cancel();
    sensation.dispose();
    super.dispose();
  }
}

class _ScopeProvider extends InheritedNotifier<AppScope> {
  const _ScopeProvider({required this.scope, required super.child}) : super(notifier: scope);
  final AppScope scope;
}

/// Convenience: the flags a region may need.
bool get isCaptureBuild => Flags.capture;
