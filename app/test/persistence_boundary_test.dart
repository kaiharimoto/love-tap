// Fails the build if any file outside lib/spine/ imports a storage driver.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An import or export of one of these packages, however it is quoted — plus the web's own
/// storage library, which needs no package at all.
RegExp _drivers(String packages) => RegExp(
      '(import|export)\\s+[\'"]package:($packages)[/\'"]'
      '|(import|export)\\s+[\'"]dart:(indexed_db|html)[\'"]',
    );

void main() {
  test('only lib/spine/ may import a storage driver', () {
    // Either quote, and an export as well as an import: Dart takes "package:hive/hive.dart"
    // exactly as it takes the single-quoted one, and this rule is the one the brief says must
    // fail the build. A rule that can be walked around by pressing a different key is not a rule.
    final drivers = _drivers(
        'sqflite|drift|hive|hive_flutter|shared_preferences|sqlite3|sqlite3_flutter_libs|'
        'idb_shim|idb_sqflite|sembast|isar|objectbox|realm');
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
    final drivers = _drivers('sqlite3|sqlite3_flutter_libs|idb_shim');
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
