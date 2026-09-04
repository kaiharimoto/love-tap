// The JS side of capture mode. capture.sh calls these through Playwright's page.evaluate; each
// answers with a string so a failed step reads as a sentence in the capture log.
import 'dart:convert';
import 'dart:js_interop';

import 'hooks.dart';

@JS('window')
external JSObject get _window;

extension type _Win(JSObject o) implements JSObject {
  external set __deskGoTo(JSFunction f);
  external set __deskScrollTo(JSFunction f);
  external set __deskSendFeeling(JSFunction f);
  external set __deskOpenCorner(JSFunction f);
  external set __deskSetSignal(JSFunction f);
  external set __deskOpenSender(JSFunction f);
  external set __deskOpenViewer(JSFunction f);
  external set __deskSearch(JSFunction f);
  external set __deskUnfold(JSFunction f);
  external set __deskShowWords(JSFunction f);
  external set __deskReport(JSFunction f);
  external set __deskScrollBy(JSFunction f);
  external set __deskStage(JSFunction f);
  external set __deskStep(JSFunction f);
}

void expose(CaptureHooks hooks) {
  final w = _Win(_window);
  w.__deskGoTo = ((JSNumber i) => hooks.goToRegion(i.toDartInt).toJS).toJS;
  w.__deskScrollTo = ((JSString a) => hooks.scrollTo(a.toDart).toJS).toJS;
  w.__deskSendFeeling = ((JSString id, JSNumber v) => hooks.sendFeeling(id.toDart, v.toDartDouble).toJS).toJS;
  w.__deskOpenCorner = ((JSBoolean open) => hooks.openCorner(open.toDart).toJS).toJS;
  w.__deskSetSignal = ((JSString s, JSString v) => hooks.setSignal(s.toDart, _value(v.toDart)).toJS).toJS;
  w.__deskOpenSender = ((JSBoolean open) => hooks.openSender(open.toDart).toJS).toJS;
  w.__deskOpenViewer = ((JSString id) => hooks.openViewer(id.toDart).toJS).toJS;
  w.__deskSearch = ((JSString q) => hooks.search(q.toDart).toJS).toJS;
  w.__deskUnfold = (() => hooks.unfoldAll().toJS).toJS;
  w.__deskShowWords = (() => hooks.showWords().toJS).toJS;
  w.__deskReport = (() => jsonEncode(hooks.report()).toJS).toJS;
  w.__deskScrollBy = ((JSNumber dy) => hooks.scrollBy(dy.toDartDouble).toJS).toJS;
  w.__deskStage = (() => hooks.stageStates().toJS).toJS;
  w.__deskStep = ((JSNumber ms) => DrivenClock.step(ms.toDartInt).toJS).toJS;
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
