// The JS side of capture mode. capture.sh calls these through Playwright's page.evaluate; each
// answers with a string so a failed step reads as a sentence in the capture log.
import 'dart:convert';
import 'dart:js_interop';

import '../main.dart' show bootPhases;
import 'hooks.dart';

@JS('window')
external JSObject get _window;

extension type _Win(JSObject o) implements JSObject {
  external set __deskGoTo(JSFunction f);
  external set __deskScrollTo(JSFunction f);
  external set __deskSendFeeling(JSFunction f);
  external set __deskOpenCorner(JSFunction f);
  external set __deskShowFamily(JSFunction f);
  external set __deskShowLens(JSFunction f);
  external set __deskSeek(JSFunction f);
  external set __deskHoldOver(JSFunction f);
  external set __deskLetGo(JSFunction f);
  external set __deskBoot(JSFunction f);
  external set __deskSetSignal(JSFunction f);
  external set __deskOpenSender(JSFunction f);
  external set __deskOpenViewer(JSFunction f);
  external set __deskSearch(JSFunction f);
  external set __deskUnfold(JSFunction f);
  external set __deskSendSlowly(JSFunction f);
  external set __deskShowWords(JSFunction f);
  external set __deskReport(JSFunction f);
  external set __deskView(JSFunction f);
  external set __deskSearchFacet(JSFunction f);
  external set __deskPair(JSFunction f);
  external set __deskScrollBy(JSFunction f);
  external set __deskStage(JSFunction f);
  external set __deskStep(JSFunction f);
  external set __deskCount(JSFunction f);
  external set __deskQuiet(JSFunction f);
  external set __deskSync(JSFunction f);
  external set __deskHaptics(JSFunction f);
  external set __deskFling(JSFunction f);
  external set __deskTimings(JSFunction f);
  external set __deskFlingLog(JSFunction f);
}

/// A handle's answer, as a string the harness can read.
///
/// `Future<String>.toJS` picks the `Future<void>` conversion, so every sentence a handle answered
/// with — 'ok', or what was missing — arrived in the browser as `undefined`, and the harness
/// learnt to accept `undefined` as success. It is a failed step that is being hidden that way:
/// the pairing step resolved to nothing for a whole capture and the scenes went on unpaired.
JSPromise<JSString> _said(Future<String> answer) => answer.then((s) => s.toJS).toJS;

void expose(CaptureHooks hooks) {
  final w = _Win(_window);
  w.__deskGoTo = ((JSNumber i) => _said(hooks.goToRegion(i.toDartInt))).toJS;
  w.__deskScrollTo = ((JSString a) => _said(hooks.scrollTo(a.toDart))).toJS;
  w.__deskSendFeeling = ((JSString id, JSNumber v) => _said(hooks.sendFeeling(id.toDart, v.toDartDouble))).toJS;
  w.__deskOpenCorner = ((JSBoolean open) => _said(hooks.openCorner(open.toDart))).toJS;
  w.__deskShowFamily = ((JSString f) => _said(Future.value(hooks.showFamily(f.toDart)))).toJS;
  w.__deskShowLens = ((JSString l) => _said(Future.value(hooks.showLens(l.toDart)))).toJS;
  w.__deskSeek = ((JSNumber f) => _said(hooks.seekViewer(f.toDartDouble))).toJS;
  w.__deskHoldOver = ((JSString id) => _said(Future.value(hooks.holdOver(id.toDart)))).toJS;
  w.__deskLetGo = (() => _said(Future.value(hooks.letGo()))).toJS;
  w.__deskBoot = (() => jsonEncode(bootPhases).toJS).toJS;
  w.__deskSetSignal = ((JSString s, JSString v) => _said(hooks.setSignal(s.toDart, _value(v.toDart)))).toJS;
  w.__deskOpenSender = ((JSBoolean open) => _said(hooks.openSender(open.toDart))).toJS;
  w.__deskOpenViewer = ((JSString id) => _said(hooks.openViewer(id.toDart))).toJS;
  w.__deskSearch = ((JSString q) => _said(hooks.search(q.toDart))).toJS;
  w.__deskUnfold = (() => _said(hooks.unfoldAll())).toJS;
  w.__deskSendSlowly = ((JSString text, JSNumber ms) =>
      _said(hooks.sendSlowly(text.toDart, ms.toDartInt))).toJS;
  w.__deskShowWords = (() => _said(hooks.showWords())).toJS;
  w.__deskReport = (() => jsonEncode(hooks.report()).toJS).toJS;
  w.__deskView = ((JSString key) => hooks.view(key.toDart).toJS).toJS;
  w.__deskSearchFacet = ((JSString f) => hooks.searchFacet(f.toDart).toJS).toJS;
  w.__deskPair = ((JSString base, JSString words) => _said(hooks.pair(base.toDart, words.toDart))).toJS;
  w.__deskScrollBy = ((JSNumber dy) => _said(hooks.scrollBy(dy.toDartDouble))).toJS;
  w.__deskStage = (() => _said(hooks.stageStates())).toJS;
  w.__deskStep = ((JSNumber ms) => DrivenClock.step(ms.toDartInt).toJS).toJS;
  w.__deskCount = (() => hooks.count().toJS).toJS;
  w.__deskQuiet = (() => hooks.quiet().toJS).toJS;
  w.__deskSync = (() => hooks.sync().toJS).toJS;
  w.__deskHaptics = (() => jsonEncode(hooks.haptics()).toJS).toJS;
  w.__deskFling = ((JSNumber v) => _said(hooks.fling(v.toDartDouble))).toJS;
  w.__deskTimings = (() => jsonEncode(hooks.timings()).toJS).toJS;
  w.__deskFlingLog = (() => jsonEncode(hooks.flingLog()).toJS).toJS;
}

/// Signal values arrive as strings on the wire; the numbers and flags among them are read back
/// out here so the spine keeps the type docs/SIGNALS.md gives the signal.
Object _value(String raw) {
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  final n = num.tryParse(raw);
  if (n != null) return n;
  return raw;
}
