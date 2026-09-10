import 'dart:js_interop';

@JS('window.__deskBoot')
external JSFunction? get _deskBoot;

@JS('window.__deskDrawn')
external JSFunction? get _deskDrawn;

void bootProgress(int done, int total) =>
    _deskBoot?.callAsFunction(null, done.toJS, total.toJS);

void bootDone() => _deskDrawn?.callAsFunction(null);
