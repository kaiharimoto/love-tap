// The JS side of capture mode. capture.sh calls these through Playwright's page.evaluate; each
// answers with a string so a failed step reads as a sentence in the capture log.
import 'dart:convert';
import 'dart:js_interop';

import '../material/fold.dart';
import '../regions/chat/blob_widgets.dart';
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
  external set __deskTextRuns(JSFunction f);
  external set __deskPair(JSFunction f);
  external set __deskScrollBy(JSFunction f);
  external set __deskSettingsScrollBy(JSFunction f);
  external set __deskStage(JSFunction f);
  external set __deskStep(JSFunction f);
  external set __deskBlobsPending(JSFunction f);
  external set __deskFoldLeft(JSFunction f);
  external set __deskFoldState(JSFunction f);
  external set __deskPaperSurfaces(JSFunction f);
  external set __deskPartnerTyping(JSFunction f);
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
  w.__deskTextRuns = (() => jsonEncode(CaptureHooks.textRuns()).toJS).toJS;
  w.__deskPair = ((JSString base, JSString words) => hooks.pair(base.toDart, words.toDart).toJS).toJS;
  w.__deskScrollBy = ((JSNumber dy) => hooks.scrollBy(dy.toDartDouble).toJS).toJS;
  w.__deskSettingsScrollBy = ((JSNumber dy) => hooks.settingsScrollBy(dy.toDartDouble).toJS).toJS;
  w.__deskStage = (() => hooks.stageStates().toJS).toJS;
  // A fraction of a millisecond, not a whole one: the harness steps by one frame of the clip it
  // is assembling, and sixty frames a second is 16.667 ms. `toDartInt` threw that 0.667 away on
  // every frame of every clip.
  w.__deskStep = ((JSNumber ms) =>
      DrivenClock.step(Duration(microseconds: (ms.toDartDouble * 1000).round())).toJS).toJS;
  // The sequence's own state, cheap enough to ask for at a single frame. `__deskFoldLeft` says
  // how much of the open is still to come and is what the take stops on; this says where the
  // playhead actually IS, which is the only thing that can tell a clip of the fold from a clip
  // of its aftermath. The harness reads it at the take's first and last frame.
  w.__deskFoldState = (() => jsonEncode(FoldFrames.state).toJS).toJS;
  // A number rather than a sentence: the harness polls it between frames and a JSON
  // parse per poll is a cost the shot does not need.
  w.__deskBlobsPending = (() => BlobCache.outstanding.toJS).toJS;
  // How much of a note's open is still to come, in microseconds. A take of the fold is as long
  // as this says and not a frame longer, so the clip cannot end on a run of settled frames.
  w.__deskFoldLeft = (() => Folds.microsecondsLeftInTheOpen.toJS).toJS;
  w.__deskPaperSurfaces = (() => jsonEncode(CaptureHooks.paperSurfaces()).toJS).toJS;
  w.__deskPartnerTyping = ((JSBoolean on) => hooks.partnerTyping(on.toDart).toJS).toJS;
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
