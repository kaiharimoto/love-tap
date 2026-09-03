// Fails the build if any file outside lib/spine/ imports a storage driver.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only lib/spine/ may import a storage driver', () {
    final drivers = RegExp(
        r"import\s+'package:(sqflite|drift|hive|hive_flutter|shared_preferences|sqlite3|sqlite3_flutter_libs|idb_shim|idb_sqflite|sembast|isar|objectbox|realm)[/']|import\s+'dart:indexed_db'");
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final normalized = f.path.replaceAll('\\', '/');
      if (normalized.startsWith('lib/spine/')) continue;
      if (drivers.hasMatch(f.readAsStringSync())) offenders.add(normalized);
    }
    expect(offenders, isEmpty, reason: 'storage drivers may only be imported under lib/spine/: $offenders');
  });

  test('inside lib/spine/, drivers live under store/ only', () {
    final drivers = RegExp(r"import\s+'package:(sqlite3|sqlite3_flutter_libs|idb_shim)[/']");
    final offenders = <String>[];
    for (final f in Directory('lib/spine').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final normalized = f.path.replaceAll('\\', '/');
      if (normalized.startsWith('lib/spine/store/')) continue;
      if (drivers.hasMatch(f.readAsStringSync())) offenders.add(normalized);
    }
    expect(offenders, isEmpty);
  });
}
