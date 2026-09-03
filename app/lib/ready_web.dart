import 'dart:js_interop';

@JS('window.__deskReady')
external set _deskReady(JSBoolean value);

/// The capture harness waits for `window.__deskReady`.
void markReady() => _deskReady = true.toJS;
