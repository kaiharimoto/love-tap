import 'hooks.dart';

/// Nothing to expose off the web: the harness drives the Android build through adb and the
/// capture activity, not through a JS bridge.
void expose(CaptureHooks hooks) {}
