// Capture mode: the handles the evidence harness drives the app by.
//
// Nothing here changes what the app is; it only lets capture.sh reach the same buttons a thumb
// would, and step the clock frame by frame so a clip is a real recording of the app rather than a
// video of a browser trying to keep up. The handles exist only when the build was started with
// CAPTURE=true, so a real build has nothing to reach.
import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show ClampingScrollSimulation;

import '../feelings/builtins.dart';
import '../flags.dart';
import '../material/assignment.dart';
import '../material/fold.dart';
import '../material/library.dart';
import '../modules/registry.dart';
import '../scope.dart';
import '../spine/projections/state.dart';
import 'bus.dart';
import 'hooks_stub.dart' if (dart.library.js_interop) 'hooks_web.dart' as impl;

/// What the harness can ask the app to do. Every entry answers with a JSON string: 'ok', or a
/// line naming what was missing, so capture.sh fails on the step rather than on the screenshot.
class CaptureHooks {
  CaptureHooks(this.scope);
  final AppScope scope;

  static CaptureHooks? _installed;
  static CaptureHooks? get installed => _installed;

  static void install(AppScope scope) {
    if (!Flags.capture) return;
    final hooks = CaptureHooks(scope);
    _installed = hooks;
    impl.expose(hooks);
  }

  Future<String> goToRegion(int index) async {
    final f = CaptureBus.goToRegion;
    if (f == null) return 'no shell';
    f(index);
    await _settle();
    return 'ok';
  }

  Future<String> scrollTo(String anchor) async {
    final f = CaptureBus.scrollTo;
    if (f == null) return 'chat is not on screen';
    await f(anchor);
    await _settle();
    return 'ok';
  }

  Future<String> sendFeeling(String feelingId, double intensity) async {
    final f = CaptureBus.sendFeeling;
    if (f == null) return 'no shell';
    await f(feelingId, intensity);
    await _settle();
    return 'ok';
  }

  Future<String> openCorner(bool open) async {
    final f = CaptureBus.openCorner;
    if (f == null) return 'no shell';
    f(open);
    await _settle();
    return 'ok';
  }

  /// Set one of my own signals, as if it had been declared on this phone or read off it.
  Future<String> setSignal(String signal, Object value, {bool declared = true}) async {
    await scope.emit(declared ? 'state_declared' : 'state_passive', {'signal': signal, 'value': value});
    await _settle();
    return 'ok';
  }

  /// Move the thread by [dy] logical pixels, once.
  Future<String> scrollBy(double dy) async {
    final f = CaptureBus.scrollBy;
    if (f == null) return 'chat is not on screen';
    f(dy);
    return 'ok';
  }

  /// Throw the thread the way a thumb does: a fling at [velocity] logical px/s that runs on the
  /// driven clock through the thread's own scroller, decelerating on Flutter's clamping physics.
  ///
  /// The scroll clip used to be the scroller nudged eleven pixels a frame — a constant-speed
  /// conveyor, which no thumb has ever produced. This is a real fling: the same simulation the
  /// list would run for a real one, stepped at the clip's frame interval, so every frame is a
  /// frame of the thread decelerating.
  Future<String> fling(double velocity) async {
    if (CaptureBus.scrollBy == null) return 'chat is not on screen';
    _flingSub?.cancel();
    final sim = ClampingScrollSimulation(position: 0, velocity: velocity);
    final t0 = DrivenClock.now;
    var moved = 0.0;
    _flingSub = DrivenClock.ticks.listen((now) {
      final t = (now - t0).inMicroseconds / 1e6;
      final x = sim.x(t);
      final dx = x - moved;
      moved = x;
      if (dx.abs() > 0.01) CaptureBus.scrollBy?.call(-dx);
      if (sim.isDone(t)) {
        _flingSub?.cancel();
        _flingSub = null;
      }
    });
    _watchTimings();
    return 'ok';
  }

  StreamSubscription<Duration>? _flingSub;
  static final List<Map<String, num>> _timings = [];
  static bool _watching = false;

  void _watchTimings() {
    if (_watching) return;
    _watching = true;
    SchedulerBinding.instance.addTimingsCallback((frames) {
      for (final f in frames) {
        _timings.add({
          'build_ms': f.buildDuration.inMicroseconds / 1000,
          'raster_ms': f.rasterDuration.inMicroseconds / 1000,
          'total_ms': f.totalSpan.inMicroseconds / 1000,
        });
      }
    });
  }

  /// The frame timings recorded since the first fling: build and raster time per frame, from
  /// the framework's own FrameTiming, under the browser the clip was captured in.
  Map<String, dynamic> timings() {
    final t = List<Map<String, num>>.from(_timings);
    num pct(String k, double q) {
      if (t.isEmpty) return 0;
      final v = t.map((m) => m[k]!).toList()..sort();
      return v[((v.length - 1) * q).round()];
    }
    return {
      'frames': t.length,
      'clock': 'driven',
      'note': 'one frame per harness step, so these are the cost of drawing a frame, not a '
          'measured refresh rate',
      'build_ms': {'p50': pct('build_ms', 0.5), 'p95': pct('build_ms', 0.95), 'max': pct('build_ms', 1.0)},
      'raster_ms': {'p50': pct('raster_ms', 0.5), 'p95': pct('raster_ms', 0.95), 'max': pct('raster_ms', 1.0)},
      'over_16ms': t.where((m) => m['total_ms']! > 16).length,
      'per_frame': t,
    };
  }

  /// Pair with the phone at [base] using the six words it is showing.
  ///
  /// The same call the setup list makes, not a shortcut past it: the words derive the key, and
  /// every request after this is signed with it. The capture harness needs it because the clip
  /// that shows a feeling crossing between two devices has to start with two devices that have
  /// actually been introduced.
  Future<String> pair(String base, String words) async {
    try {
      await scope.transport.completePairing(base, words);
      await _settle();
      return 'ok';
    } catch (e) {
      return 'pairing was refused: $e';
    }
  }

  /// Every delivery state at once, made rather than drawn.
  ///
  /// The try is not decoration. A Dart exception crossing into JS arrives at the harness as
  /// `Dart exception thrown from converted Future. Use the properties 'error' to fetch the boxed
  /// error` — which is a sentence about the bridge, not about what went wrong, and it is all the
  /// scene log had to show for an artifact that failed three runs in a row. Every handle that can
  /// fail says what failed.
  Future<String> stageStates() async {
    final f = CaptureBus.stageStates;
    if (f == null) return 'the shell is not up';
    try {
      await f();
    } catch (e, stack) {
      return 'staging the states threw: $e\n${stack.toString().split('\n').take(4).join('\n')}';
    }
    await _settle();
    return 'ok';
  }

  Future<String> openSender(bool open) async {
    final f = CaptureBus.openSender;
    if (f == null) return 'chat is not on screen';
    f(open);
    await _settle();
    return 'ok';
  }

  Future<String> openViewer(String eventId) async {
    final f = CaptureBus.openViewer;
    if (f == null) return 'chat is not on screen';
    try {
      await f(eventId);
    } on StateError catch (e) {
      return e.message;
    }
    await _settle();
    return 'ok';
  }

  Future<String> search(String query) async {
    final f = CaptureBus.search;
    if (f == null) return 'chat is not on screen';
    await f(query);
    await _settle();
    return 'ok';
  }

  /// Open every folded note on screen. No settle: the clip's frames begin on the very next step
  /// of the clock, so the first frame grabbed is the first frame of the sequence rather than the
  /// fourth, and the landing before it runs straight into the opening with nothing skipped.
  Future<String> unfoldAll() async {
    final f = CaptureBus.unfoldAll;
    if (f == null) return 'chat is not on screen';
    f();
    await Future<void>.delayed(Duration.zero);
    return 'ok';
  }

  /// How many rows the thread holds: what the harness watches to know that something the far
  /// phone was told to send has actually arrived, so a clip of an arrival starts on the arrival.
  int count() => scope.thread.items.length;

  /// Every feeling this phone knows, with the pattern it plays: the evidence that thirty-odd
  /// feelings are each their own rhythm, written from the registry the app plays from rather than
  /// from a document about it. Authored feelings are in the same list because they are in the same
  /// registry.
  Map<String, dynamic> haptics() {
    final all = scope.feelings.all;
    final rows = [
      for (final f in all)
        {
          'id': f.id,
          'name': f.name,
          'family': f.family.label,
          'authored_by': f.authoredBy,
          'retired': f.retired,
          'object': f.object,
          'sound': f.sound,
          'colour': f.colour,
          'haptic': f.haptic,
          'segments': [for (final s in f.segments) {'ms': s.ms, 'amp': s.amp}],
          'total_ms': f.hapticLengthMs,
          'on_ms': f.segments.where((s) => s.on).fold<int>(0, (n, s) => n + s.ms),
          'pulses': f.segments.where((s) => s.on).length,
        }
    ];
    final byPattern = <String, List<String>>{};
    for (final f in all) {
      byPattern.putIfAbsent(f.haptic, () => []).add(f.id);
    }
    return {
      'notation': 'on@amp pairs separated by off gaps, in milliseconds, amplitude 0-255: the shape '
          'Android VibrationEffect.createWaveform takes; on the PWA the same segments move the page',
      'channel_here': scope.transport.role.name == 'host' ? 'vibration' : 'page',
      'feelings': rows,
      'built_in': all.where((f) => f.builtIn).length,
      'authored': all.where((f) => !f.builtIn).length,
      'families': {for (final f in all) f.family.label: all.where((x) => x.family == f.family).length},
      'shared_patterns': {for (final e in byPattern.entries) if (e.value.length > 1) e.key: e.value},
    };
  }

  Future<String> showWords() async {
    final f = CaptureBus.showWords;
    if (f == null) return 'settings is not on screen';
    await f();
    await _settle();
    return 'ok';
  }

  /// Everything the capture log needs: what is on screen and what produced it. The tear and stock
  /// ids are recomputed from the same assignment the renderer used, so tools/check/tear_repeat.py
  /// is checking the frame rather than trusting a note the app left itself.
  Map<String, dynamic> report() {
    final region = CaptureBus.regionIndex;
    final chat = region == 1 ? (CaptureBus.chatReport?.call() ?? const <String, dynamic>{}) : const <String, dynamic>{};
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final visible = (chat['visible'] as List?)?.cast<String>() ?? const <String>[];
    final rows = {for (var i = 0; i < scope.thread.items.length; i++) scope.thread.items[i].id: i};
    final byId = {for (final e in scope.spine.all) e.id: e};
    final tears = <String, String?>{};
    final stocks = <String, String>{};
    for (final id in visible) {
      final e = byId[id];
      if (e == null || lib == null) continue;
      tears[id] = tearFor(e, lib, row: rows[id] ?? 0);
      stocks[id] = stockVariantFor(e, lib);
    }
    return {
      'region': region,
      // what the region on screen is actually showing — Chat's rows were reported for every
      // region for a whole cycle, and the logs for four of them described notes not in the frame
      'view': _viewOf(region),
      'visible': visible,
      'tears': tears,
      'stocks': stocks,
      'scroll': chat['scroll'],
      'now': scope.clock.now().toIso8601String(),
      'driven_ms': DrivenClock.now.inMilliseconds,
      'seed': Flags.captureSeed,
      'events': scope.spine.length,
      'transport': scope.transport.name,
      'link': scope.link.state.name,
      'me': scope.me.name,
      'masks_in_pool': lib?.tearMasks.length ?? 0,
      'writable_masks': lib?.writableTears.length ?? 0,
      // What the app is lit by, and whether the library it is drawing from actually has that
      // half baked. A dusk build with no dusk paper in it looks exactly like a day build, and
      // the crop taken from it came out byte-identical to the day one.
      'light': Flags.light,
      'has_dusk_paper': lib?.hasDusk ?? false,
      'paper_stocks': lib?.paper.length ?? 0,
      'setup_showing': CaptureBus.setupShowing,
      // a clip of a note opening that does not open is either a sequence nothing asked to play
      // or a sequence whose frames never decoded, and from the outside they look the same
      'fold': FoldFrames.state,
      // the last feeling this phone played, pattern and channel: the haptic annotation on the
      // clips is generated from this, not drawn from the docs
      'sensation': scope.sensation.last?.toJson(),
      // what the off-app surfaces were handed — recorded as what was sent, never as a picture
      // of a notification this container cannot show
      'ambient': {
        'standing_line': scope.lastStandingLine,
        'pocket_feeling': scope.lastPocketFeeling,
        'pocket_at': scope.lastPocketAt,
        'allowed_to_interrupt': scope.ambient.allowed,
      },
    };
  }

  /// The region's own account of itself, from the same projections it draws from.
  Map<String, dynamic> _viewOf(int region) {
    final all = scope.spine.all;
    switch (region) {
      case 0:
        final since = scope.clock.now().subtract(const Duration(hours: 24)).millisecondsSinceEpoch;
        final recent = feelingsSince(all, since);
        return {
          'region': 'pulse',
          'recent_feelings': [
            for (final e in recent)
              {'id': e.id, 'feeling': e.payload['feeling_id'], 'from': e.author.name, 'ts': e.ts}
          ],
          'partner_signals': {for (final k in scope.partnerState.signals.keys) k: scope.partnerState.signals[k]?.value},
          'my_signals': {for (final k in scope.myState.signals.keys) k: scope.myState.signals[k]?.value},
        };
      case 1:
        final chat = CaptureBus.chatReport?.call() ?? const <String, dynamic>{};
        return {
          'region': 'chat',
          'composer': chat['composer'],
          'attaching': chat['attaching'],
          'replying_to': chat['replying_to'],
          'editing': chat['editing'],
          'partner_typing': scope.partnerTyping,
          if (chat['search'] != null) 'search': chat['search'],
          if (chat['viewer'] != null) 'viewer': chat['viewer'],
        };
      case 2:
        return {
          'region': 'us',
          'modules': [
            for (final m in kModules)
              {
                'id': m.id,
                'events': all.where((e) => m.eventTypes.contains(e.type)).length,
                'glance': m.glance(all),
              }
          ],
        };
      case 3:
        return {'region': 'moments', ...?CaptureBus.momentsReport?.call()};
      case 4:
        final pairing = scope.transport.pairing;
        return {
          'region': 'settings',
          'paired': pairing != null,
          'devices': pairing == null ? const [] : [pairing.hostId, pairing.clientId],
          'link': scope.link.state.name,
          'authored_feelings': scope.feelings.active.where((f) => !f.builtIn).length,
        };
      default:
        return {'region': 'setup'};
    }
  }

  /// Let the framework finish what the handle started before the harness takes the shot.
  static Future<void> _settle() async {
    for (var i = 0; i < 3; i++) {
      await Future<void>.delayed(Duration.zero);
      await DrivenClock.step(16);
    }
  }
}

/// The driven clock: in capture mode animations advance only when the harness says so, so every
/// frame of a clip is a real frame of the app at a known time.
class DrivenClock {
  static bool get enabled => Flags.capture;
  static Duration _now = Duration.zero;
  static final StreamController<Duration> _ticks = StreamController.broadcast();

  static Duration get now => _now;
  static Stream<Duration> get ticks => _ticks.stream;

  /// Advance by [ms] and let the framework produce exactly one frame.
  static Future<void> step(int ms) async {
    _now += Duration(milliseconds: ms);
    if (_ticks.hasListener) _ticks.add(_now);
    final done = Completer<void>();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!done.isCompleted) done.complete();
    });
    SchedulerBinding.instance.scheduleFrame();
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }
}
