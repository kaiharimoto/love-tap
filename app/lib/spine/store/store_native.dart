// Android (and any dart:io host): where the sqlite file goes, and nothing else.
//
// The store is in store_sqlite.dart. This is the half that asks the platform for a directory,
// which is the half that needs Flutter.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'store.dart';
import 'store_sqlite.dart';

export 'store_sqlite.dart' show NativeStore;

Future<SpineStore> openStore(String profile) async {
  final dir = await _dataDir(profile);
  return NativeStore.openAt(p.join(dir, 'spine.sqlite3'));
}

Future<String> _dataDir(String profile) async {
  final override = Platform.environment['LOVETAP_DATA_DIR'];
  final base = override ?? (await getApplicationSupportDirectory()).path;
  final dir = Directory(p.join(base, 'profiles', profile));
  await dir.create(recursive: true);
  return dir.path;
}
