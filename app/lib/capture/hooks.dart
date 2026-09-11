// Capture mode: the handles the evidence harness drives the app by.
//
// Nothing here changes what the app is; it only lets capture.sh reach the same buttons a thumb
// would, and step the clock frame by frame so a clip is a real recording of the app rather than a
// video of a browser trying to keep up. The handles exist only when the build was started with
// CAPTURE=true, so a real build has nothing to reach.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter/widgets.dart' show ClampingScrollSimulation;

import '../feelings/builtins.dart';
import '../feelings/landing.dart';
import '../flags.dart';
import '../material/assignment.dart';
import '../regions/chat/blob_widgets.dart';
import '../material/fold.dart';
import '../material/library.dart';
import '../material/paper.dart';
import '../modules/registry.dart';
import '../scope.dart';
import '../spine/projections/state.dart';
import '../feelings/sensation.dart' show Sensation;
import '../main.dart' show bootPhases;
import '../regions/chat/note.dart' show ThreadRowStats;
import 'bus.dart';
import 'hooks_stub.dart' if (dart.library.js_interop) 'hooks_web.dart' as impl;

/// What the harness can ask the app to do. Every entry answers with a JSON string: 'ok', or a
/// line naming what was missing, so capture.sh fails on the step rather than on the screenshot.
class CaptureHooks {
  CaptureHooks(this.scope);
  final AppScope scope;

  static CaptureHooks? _installed;
  static CaptureHooks? get installed => _installed;

  /// What the phone is holding in its own notification store, kept fresh so the synchronous
  /// report can carry it. Real time rather than the driven clock: this is not an animation, and
  /// the arrival being recorded happens while nothing in the app is being stepped.
  static List<Map<String, Object?>> _heldByThePhone = const [];
  static Timer? _ambientPoll;

  static void install(AppScope scope) {
    if (!Flags.capture) return;
    final hooks = CaptureHooks(scope);
    _installed = hooks;
    impl.expose(hooks);
    _ambientPoll?.cancel();
    _ambientPoll = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      _heldByThePhone = await scope.ambient.received();
    });
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

  /// Every frame of every throw: what the simulation asked for, what the thread actually moved,
  /// and where it was sitting when it did. A clip with a frame identical to the one before it is
  /// either a race in the grab or a thread that stood still, and this is how they are told apart.
  static final List<Map<String, Object?>> _flingFrames = [];

  Map<String, dynamic> flingLog() {
    final f = List<Map<String, Object?>>.from(_flingFrames);
    final still = f.where((m) => (m['moved'] as double).abs() < 0.34).toList();
    return {
      'unit': 'logical pixels; a frame that moved less than a third of one is under a device '
          'pixel at the clip\'s scale and can come back as the frame before it',
      'frames': f,
      'throws': f.where((m) => m['throw'] == true).length,
      'frames_under_a_device_pixel': still.length,
      'at': still.map((m) => m['tick']).toList(),
      // How much of the thread the throws actually covered. A messenger critic worked this out
      // from two numbers in two files and read one to three per cent; it belongs in the log that
      // records the throws.
      'travelled': f.fold<double>(0.0, (a, m) => a + ((m['moved'] as double?) ?? 0).abs()).round(),
      'the_thread_is': f.isEmpty ? null : (f.last['end'] as num?)?.round(),
      'share_of_the_thread': f.isEmpty || (f.last['end'] as num? ?? 0) <= 0
          ? null
          : double.parse((f.fold<double>(0.0, (a, m) => a + ((m['moved'] as double?) ?? 0).abs()) /
                  (f.last['end'] as num) * 100)
              .toStringAsFixed(2)),
      'rows_built_total': f.fold<int>(0, (a, m) => a + ((m['rows_built'] as int?) ?? 0)),
      'rows_built_worst_tick': f.fold<int>(0, (a, m) {
        final n = (m['rows_built'] as int?) ?? 0;
        return n > a ? n : a;
      }),
    };
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
    var first = true;
    var builtBefore = ThreadRowStats.built;
    _flingSub = DrivenClock.ticks.listen((now) {
      final t = (now - t0).inMicroseconds / 1e6;
      final x = sim.x(t);
      final dx = x - moved;
      moved = x;
      final at = CaptureBus.scrollWhere?.call() ?? const <double>[];
      final went = dx.abs() > 0.001 ? (CaptureBus.scrollBy?.call(-dx) ?? 0.0) : 0.0;
      _flingFrames.add({
        'tick': DrivenClock.steps,
        'throw': first,
        't_ms': (t * 1000).round(),
        'asked': double.parse((-dx).toStringAsFixed(3)),
        'moved': double.parse(went.toStringAsFixed(3)),
        'from': at.isEmpty ? null : double.parse(at[0].toStringAsFixed(1)),
        'end': at.isEmpty ? null : double.parse(at[2].toStringAsFixed(1)),
        // how many thread rows the framework asked for on this tick. A viewport holds about
        // eight notes: eight means the cost is per row, thousands means the list is not lazy.
        'rows_built': ThreadRowStats.built - builtBefore,
      });
      builtBefore = ThreadRowStats.built;
      first = false;
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
    var rowsBefore = ThreadRowStats.built;
    var piecesBefore = PaperPiece.drawnNative + PaperPiece.drawnStretched;
    var masksBefore = SlicedMasks.composed;
    SchedulerBinding.instance.addTimingsCallback((frames) {
      for (final f in frames) {
        // What the frame did, beside what it cost.
        //
        // Three cycles of argument about the scroll rested on a number with nothing beside it: 182
        // frames over 400 ms, recurring every three to seven frames, and no way to tell from the
        // record whether a heavy frame built a row, composed a mask, or was the browser collecting
        // half a gigabyte of held images. These are counters the app already keeps; the difference
        // across a frame is what that frame did.
        final rows = ThreadRowStats.built;
        final pieces = PaperPiece.drawnNative + PaperPiece.drawnStretched;
        final masks = SlicedMasks.composed;
        _timings.add({
          'build_ms': f.buildDuration.inMicroseconds / 1000,
          'raster_ms': f.rasterDuration.inMicroseconds / 1000,
          'total_ms': f.totalSpan.inMicroseconds / 1000,
          'rows_built': rows - rowsBefore,
          'pieces_drawn': pieces - piecesBefore,
          'masks_composed': masks - masksBefore,
        });
        rowsBefore = rows;
        piecesBefore = pieces;
        masksBefore = masks;
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
      // A messenger critic read `over_16ms: 778 of 778` as the app never once drawing a frame in
      // under sixteen milliseconds, which is what the number says and not what it means. The
      // capture runs headless WebKit in a container with no GPU: CanvasKit falls back to a
      // software rasteriser, and raster time here is a property of that, not of a phone. Build
      // time is the app's own work and is the number worth reading.
      'build_is_the_app': 'build_ms is the framework laying out and painting: the app\'s own '
          'work, and comparable between runs',
      'raster_is_the_machine': 'raster_ms is CanvasKit turning that into pixels. This capture has '
          'no GPU — headless WebKit in a container falls back to a software rasteriser — so '
          'raster_ms says what this machine costs, not what a phone would. over_16ms counts '
          'build plus raster and is therefore about the machine as much as the app.',
      'build_ms': {'p50': pct('build_ms', 0.5), 'p95': pct('build_ms', 0.95), 'max': pct('build_ms', 1.0)},
      'raster_ms': {'p50': pct('raster_ms', 0.5), 'p95': pct('raster_ms', 0.95), 'max': pct('raster_ms', 1.0)},
      'over_16ms': t.where((m) => m['total_ms']! > 16).length,
      // What the expensive frames were doing, summed — so the next argument about the scroll starts
      // from what happened rather than from what is plausible.
      'the_heavy_frames': () {
        final heavy = t.where((m) => m['build_ms']! > 400).toList();
        num sum(String k, Iterable<Map<String, num>> rows) =>
            rows.fold<num>(0, (n, m) => n + (m[k] ?? 0));
        return {
          'over_400ms': heavy.length,
          'their_build_ms': sum('build_ms', heavy).round(),
          'all_build_ms': sum('build_ms', t).round(),
          'rows_they_built': sum('rows_built', heavy),
          'pieces_they_drew': sum('pieces_drawn', heavy),
          'masks_they_composed': sum('masks_composed', heavy),
          'rows_built_in_all': sum('rows_built', t),
          'pieces_drawn_in_all': sum('pieces_drawn', t),
        };
      }(),
      'masks_held_at_the_end': MaskCache.held,
      'masks_dropped': MaskCache.dropped,
      'image_cache_at_the_end': {
        'held': PaintingBinding.instance.imageCache.currentSize,
        'bytes': PaintingBinding.instance.imageCache.currentSizeBytes,
        'budget': PaintingBinding.instance.imageCache.maximumSizeBytes,
        'live': PaintingBinding.instance.imageCache.liveImageCount,
      },
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

  /// Turn the vocabulary to a family and say how many feelings are on the sheet. What lets a clip
  /// hold the vocabulary open and go through it, rather than showing that a sheet exists.
  String showFamily(String family) {
    final f = CaptureBus.showFamily;
    if (f == null) return 'the corner is not on screen';
    final n = f(family);
    return n > 0 ? 'ok, $n on the sheet' : 'no feelings in $family';
  }

  /// Put the finger on a feeling and start the hold.
  String holdOver(String id) {
    final f = CaptureBus.holdOver;
    if (f == null) return 'the corner is not on screen';
    return f(id) ? 'ok, holding $id' : 'no feeling called $id';
  }

  /// Lift the finger; whatever was under it goes.
  String letGo() {
    final f = CaptureBus.letGo;
    if (f == null) return 'the corner is not on screen';
    final at = f();
    return at < 0 ? 'nothing was under the finger' : 'ok, sent at ${at.toStringAsFixed(2)}';
  }

  /// Turn Moments to a lens and say how many rows are behind it.
  String showLens(String lens) {
    final f = CaptureBus.showLens;
    if (f == null) return 'moments is not on screen';
    final n = f(lens);
    return n >= 0 ? 'ok, $n behind $lens' : 'no lens called $lens';
  }

  /// Move the film's playhead to a fraction of its length.
  Future<String> seekViewer(double fraction) async {
    final f = CaptureBus.seekViewer;
    if (f == null) return 'no film is open';
    final at = await f(fraction);
    await _settle();
    return at < 0 ? 'the film is not ready' : 'ok, at ${at}ms';
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
  /// Write one and leave it on its way, so the picture catches a row that is sending.
  Future<String> sendSlowly(String text, int slowMs) async {
    final f = CaptureBus.sendSlowly;
    if (f == null) return 'chat is not on screen';
    try {
      await f(text, slowMs);
    } catch (e) {
      return 'sending slowly threw: $e';
    }
    await _settle();
    return 'ok';
  }

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

  /// Ask for a sync round now, the way opening the app does. The harness waits for something the
  /// far phone sent, and a pull that has just backed off would otherwise leave it waiting.
  String sync() {
    scope.sync.kick();
    return 'ok';
  }

  /// 'ok' when no picture is still being read out of the store: what a shot waits for, so a still
  /// of Moments is a still of the prints and not of the moment before they were decoded. The blob
  /// reads are the slow part under capture; the decode after them is inside the shot's own settle.
  /// Put a facet on in the search that is open: `photographs`, `talking`, a module's own name.
  String searchFacet(String facet) {
    final f = CaptureBus.searchFacet;
    if (f == null) return 'no search is open';
    return f(facet.isEmpty ? null : facet);
  }

  String quiet() {
    final b = BlobCache.stats();
    // and no paper still on its way: a piece keeps its room and paints nothing until its mask has
    // decoded, so a frame grabbed now is a frame with a hole in it where a note should be.
    final masks = MaskCache.decoding;
    // And no *stock* still on its way, which is not the same thing and was not being waited for.
    //
    // A piece's tear mask goes through MaskCache and its stock goes through Flutter's own image
    // cache, and only the first was counted here. So a piece whose mask had arrived and whose
    // stock had not drew its torn edge over the flat fallback colour — a perfectly flat cream
    // shape with a real fringe on it, which is the exact shape the material row fails a build for.
    // Measured on the twelfth capture: one 80-pixel window of 04_moments at standard deviation
    // 0.017 grey levels, inside a voice-note tile whose fringe is plainly drawn. It is not a fill
    // standing in for paper; it is paper that had not arrived when the shutter opened.
    final stock = PaintingBinding.instance.imageCache.pendingImageCount;
    // And the outcome as well as the queue: `pendingImageCount` counts what is being decoded, and
    // a piece can be on the glass waiting for a stock whose load has not been started yet.
    final without = PaperPiece.waitingForPaper;
    if ((b['reading'] ?? 0) == 0 &&
        (b['waiting'] ?? 0) == 0 &&
        masks == 0 &&
        stock == 0 &&
        without.isEmpty) {
      return 'ok';
    }
    return 'reading ${b['reading']}, waiting ${b['waiting']}, decoding $masks, stock $stock'
        '${without.isEmpty ? '' : ', no paper yet for ${(without.toList()..sort()).join(', ')}'}';
  }

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
          // Which way this one knocks the desk on a phone with no vibrator, and how far it turns
          // it. An emotional critic measured the page translation in all 421 frames of 07 and
          // found the horizontal component exactly zero in every one: the substitute was a
          // bounce. It is the feeling's own direction now, and here is the number for it.
          'knocks_the_desk': {
            'x': double.parse(knockDirection(f.id).dx.toStringAsFixed(4)),
            'y': double.parse(knockDirection(f.id).dy.toStringAsFixed(4)),
            'turns_it_by_radians': double.parse(knockTilt(f.id).toStringAsFixed(5)),
            'at_full_lift_px': double.parse((kPageLiftPx).toStringAsFixed(1)),
          },
        }
    ];
    final byPattern = <String, List<String>>{};
    for (final f in all) {
      byPattern.putIfAbsent(f.haptic, () => []).add(f.id);
    }
    return {
      'notation': 'on@amp pairs separated by off gaps, in milliseconds, amplitude 0-255: the shape '
          'Android VibrationEffect.createWaveform takes; on the PWA the same segments move the page',
      'how_the_page_moves': 'the same envelope, as a push in the direction under knocks_the_desk '
          'and a turn of the whole board with it. Sideways is never further than up, because a '
          'page that slides as far as it lifts reads as a swipe; the turn is under a quarter of a '
          'degree, which is enough that a corner travels further than the middle.',
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
  /// One field of what the app is showing, without building the rest of the report.
  ///
  /// A scene that waits for something on the glass — the partner writing, a player playing —
  /// used to poll the whole report every quarter second, and the whole report is the region's own
  /// account of every row on it. So the wait was measured in seconds, and the shutter opened on a
  /// moment several of them after the one the scene had waited for: 13's record said the partner
  /// was not writing because the six-second lapse on a typing frame had run out in between. This
  /// answers the one question.
  String view(String key) {
    final v = switch (key) {
      'partner_typing' => scope.partnerTyping,
      'region' => CaptureBus.regionIndex,
      'link' => scope.link.state.name,
      'setup_showing' => CaptureBus.setupShowing,
      _ => _fromTheRegion(key),
    };
    return jsonEncode(v);
  }

  Object? _fromTheRegion(String key) {
    Object? at = _viewOf(CaptureBus.regionIndex);
    for (final part in key.split('.')) {
      if (at is Map && at.containsKey(part)) {
        at = at[part];
      } else {
        return null;
      }
    }
    return at;
  }

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
      // which of those rows are a piece of paper with a torn edge, as against a pencil line in
      // the margin or a thrown object. tools/check/tears.py counts the hero's notes off this:
      // the tear ids are recomputed for every visible row, and counting a margin line among them
      // would let the frame meet a standard about torn edges without carrying one.
      'paper': chat['paper'] ?? const <String>[],
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
      // How many tear masks this run has had to bake into an image rather than draw. It
      // should be nothing: a piece draws its tear as a nine-patch straight into the
      // canvas, and only a piece whose subtree pushes a compositing layer of its own has
      // to compose one — hundreds of milliseconds in CanvasKit, on the build thread, once
      // a note as the thread scrolls. Three cycles of claims about the scroll rested on a
      // probe; this is the artifact saying it.
      'masks_composed': SlicedMasks.composed,
      'writable_masks': lib?.writableTears.length ?? 0,
      // What the app is lit by, and whether the library it is drawing from actually has that
      // half baked. A dusk build with no dusk paper in it looks exactly like a day build, and
      // the crop taken from it came out byte-identical to the day one.
      'light': Flags.light,
      'has_dusk_paper': lib?.hasDusk ?? false,
      'paper_stocks': lib?.paper.length ?? 0,
      // How many pieces on this screen were drawn at the stock's own density and how many were
      // stretched to fit. A stretched piece is paper at the wrong size, which is the fault behind
      // three measurements: the tooth spread thin on a wide sheet, the same ruled stock at pitches
      // 2.9 times apart across the set, and writing that cannot sit on lines whose spacing is
      // different on every screen.
      'the_smallest_patch_of_a_stock_anything_took': PaperPiece.smallestWindow,
      'paper_at_its_own_size': PaperPiece.drawnNative,
      'paper_stretched_to_fit': PaperPiece.drawnStretched,
      // Which stocks a piece had asked for and not got when the frame was taken, and where the
      // memory that decides that went. A stock that has not arrived paints as the flat colour
      // underneath it, and in a still that is indistinguishable from paper with no tooth: six
      // cream rectangles in 04_moments, 260,907 pixels of one exact value, torn fringe drawn
      // perfectly around every one of them. Nothing in this report said so, because every counter
      // here recorded a decision rather than its outcome.
      'stocks_the_paper_had_not_arrived_for': PaperPiece.waitingForPaper.toList()..sort(),
      'paper_that_arrived_after_the_piece_was_drawn': PaperPiece.paperArrivedLate,
      'masks_held': MaskCache.held,
      'masks_dropped_to_stay_inside_the_pool': MaskCache.dropped,
      'image_cache': {
        'held': PaintingBinding.instance.imageCache.currentSize,
        'bytes': PaintingBinding.instance.imageCache.currentSizeBytes,
        'budget': PaintingBinding.instance.imageCache.maximumSizeBytes,
        'live': PaintingBinding.instance.imageCache.liveImageCount,
        'still_decoding': PaintingBinding.instance.imageCache.pendingImageCount,
      },
      'setup_showing': CaptureBus.setupShowing,
      // a clip of a note opening that does not open is either a sequence nothing asked to play
      // or a sequence whose frames never decoded, and from the outside they look the same
      'fold': FoldFrames.state,
      // the last feeling this phone played, pattern and channel: the haptic annotation on the
      // clips is generated from this, not drawn from the docs
      'sensation': scope.sensation.last?.toJson(),
      // and every ask the app made of a motor on this run, with what answered. There is no motor
      // in a browser and no phone in this environment, and an emotional critic read that as the
      // haptic channel not being exercised at all. It is exercised; nothing answers. Those are
      // different, and this is where the difference is written down.
      // Always present, even when it is empty and even on a platform with no motor: the point of
      // the record is that the ask and the answer are both written down, and a key that vanishes
      // when there is nothing to say is a record that only ever reports success.
      'asked_a_motor_for': List.of(Sensation.asks),
      // what the first launch was made of, rather than one number for all of it
      if (bootPhases.isNotEmpty) 'the_launch_took': Map.of(bootPhases),
      // what the off-app surfaces were handed — recorded as what was sent, never as a picture
      // of a notification this container cannot show
      'sync': scope.sync.report(),
      'ambient': {
        'standing_line': scope.lastStandingLine,
        'pocket_feeling': scope.lastPocketFeeling,
        'pocket_at': scope.lastPocketAt,
        'allowed_to_interrupt': scope.ambient.allowed,
        // Two of the three surfaces name the feeling and one cannot, and an emotional critic read
        // the one that cannot and concluded none of them do: "outside the app a feeling is reduced
        // to 'noor / is holding something out' ... the same eight words stand for [everything]".
        // That is the *push* — delivered when the app is not running — and it is eight words on
        // purpose. tools/push/webpush.py: "a push payload may carry the event kind and who sent
        // it, and nothing else. Not the text, not the feeling's name." Two people's phones do not
        // hand a push service the contents of what they send each other. The pocket surface, which
        // runs in the app, has the feeling in hand and puts its name in the title.
        'what_each_surface_may_say': {
          'standing_line': 'their state, in the couple\'s own words, assembled here from the log',
          'pocket': 'the feeling\'s own name and its sound, because the app is running and has it',
          'push': 'the kind and the sender, and nothing else, by the rule in tools/push/webpush.py '
              '— a lock screen is not a place to put what two people said to each other',
        },
        // what this app asked for is above; what the phone is holding is below, read back from
        // the platform, so the record is not four statements of intent
        'held_by_the_phone': _heldByThePhone,
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
          // and what the two sheets are made of: a signal either of them declared, and one their
          // phone reported on its own
          'kinds': () {
            final counts = <String, int>{};
            for (final e in all) {
              if (e.type == 'state_declared' || e.type == 'state_passive' || e.type == 'feeling' ||
                  e.type == 'feeling_authored' || e.type == 'ping') {
                counts[e.type] = (counts[e.type] ?? 0) + 1;
              }
            }
            return counts;
          }(),
          'partner_signals': {for (final k in scope.partnerState.signals.keys) k: scope.partnerState.signals[k]?.value},
          'my_signals': {for (final k in scope.myState.signals.keys) k: scope.myState.signals[k]?.value},
        };
      case 1:
        // whichever of the three is actually on the glass
        final viewing = CaptureBus.viewerReport?.call();
        if (viewing != null) {
          return {'region': 'viewer', 'over': 'chat', ...viewing};
        }
        final searching = CaptureBus.searchReport?.call();
        if (searching != null) {
          return {'region': 'search', 'over': 'chat', ...searching};
        }
        final chat = CaptureBus.chatReport?.call() ?? const <String, dynamic>{};
        // Everything the region recorded, not a hand-copied list of it. This used to name
        // thirteen keys one at a time, and the two the last cycle added — `replies_on_the_glass`,
        // which exists because a messenger critic capped the row on there being no delivered
        // reply in any record, and `clipped_at_an_edge`, which exists because a report counted a
        // read mark on a row that was 125 device pixels of blank paper — were written by the
        // region and dropped here. A record that knows less than the build does is worse than no
        // record: it is a record that can be believed.
        return {
          'region': 'chat',
          ...chat,
          'partner_typing': scope.partnerTyping,
        };
      case 2:
        return {
          'region': 'us',
          // what kinds of thing the five modules are drawing between them, so the record names the
          // eleven types that live outside the thread rather than leaving them to the eye
          'kinds': () {
            final mine = {for (final m in kModules) ...m.eventTypes};
            final counts = <String, int>{};
            for (final e in all) {
              if (mine.contains(e.type)) counts[e.type] = (counts[e.type] ?? 0) + 1;
            }
            return counts;
          }(),
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

  /// How many steps have been taken. A clip grabs one frame per step, so this is the frame the
  /// fling's log is talking about.
  static int steps = 0;
  static final StreamController<Duration> _ticks = StreamController.broadcast();

  static Duration get now => _now;
  static Stream<Duration> get ticks => _ticks.stream;

  /// Advance by [ms] and let the framework produce exactly one frame.
  static Future<void> step(int ms) async {
    _now += Duration(milliseconds: ms);
    steps += 1;
    if (_ticks.hasListener) _ticks.add(_now);
    // Two frames, not one. A widget that finishes its work in a post-frame callback — the
    // positioned list settles a jump that way — is drawn a frame late, and with one frame a step
    // every other grab of a scroll clip was the grab before it, followed by a double step.
    for (var pass = 0; pass < 2; pass++) {
      final done = Completer<void>();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!done.isCompleted) done.complete();
      });
      SchedulerBinding.instance.scheduleFrame();
      await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    }
  }
}
