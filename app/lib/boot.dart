// What the page shows before there is a Flutter frame to show anything with.
//
// The first launch reads a year out of the browser's store and that took eight to ten seconds in
// five scene logs, against two on a phone that already has it. `runApp` is not called until the
// log is open, so for the whole of it the page is whatever index.html is — and until now that was
// a flat rectangle of the desk's colour. The page now puts the desk out itself; these two calls
// are how Dart tells it where the reading has got to, and when to take it away.
import 'boot_stub.dart' if (dart.library.js_interop) 'boot_web.dart' as impl;

/// How much of the log has been read back, in months, while the page is still the page.
void bootProgress(int done, int total) => impl.bootProgress(done, total);

/// The app has drawn. Whatever the page put out can go.
void bootDone() => impl.bootDone();
