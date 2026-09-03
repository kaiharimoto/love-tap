// One flag the capture harness waits on, so a screenshot is never a guess about timing.
import 'ready_stub.dart' if (dart.library.js_interop) 'ready_web.dart' as impl;

void markReady() => impl.markReady();
