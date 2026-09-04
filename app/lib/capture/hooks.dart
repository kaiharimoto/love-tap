// Capture mode: the handles the evidence harness drives the app by.
//
// Nothing here changes what the app is; it only lets capture.sh reach the same buttons a thumb
// would, and step the clock frame by frame so a clip is a real recording of the app rather than a
// video of a browser trying to keep up. The handles exist only when the build was started with
// CAPTURE=true, so a real build has nothing to reach.
import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../flags.dart';
import '../material/assignment.dart';
import '../material/fold.dart';
import '../material/library.dart';
import '../scope.dart';
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
  Future<String> stageStates() async {
    final f = CaptureBus.stageStates;
    if (f == null) return 'the shell is not up';
    await f();
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

  Future<String> unfoldAll() async {
    final f = CaptureBus.unfoldAll;
    if (f == null) return 'chat is not on screen';
    f();
    await _settle();
    return 'ok';
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
    final chat = CaptureBus.chatReport?.call() ?? const <String, dynamic>{};
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
      'region': CaptureBus.regionIndex,
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
    };
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
