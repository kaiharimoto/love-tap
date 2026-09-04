// Which store, and where its file goes: the one place that names a platform.
//
// Kept apart from store.dart so that reaching the interface does not reach a driver. See the note
// there; the short version is that a headless Dart process has no dart:ui and must still be able
// to open a spine.
import 'store.dart';

import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart' as impl;

Future<SpineStore> openStore(String profile) => impl.openStore(profile);
