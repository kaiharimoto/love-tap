// Fails the build if any file outside lib/spine/ imports a storage driver.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An import or export of one of these packages, however it is quoted and wherever in the
/// directive it appears — plus the web's own storage library, which needs no package at all.
///
/// It used to require the package URI to follow `import` or `export` directly, which a
/// conditional import walks straight past: `import 'stub.dart' if (dart.library.io)
/// 'package:sqlite3/sqlite3.dart';` is exactly how this codebase reaches a platform's driver, and
/// exactly the form the rule could not see. A code critic probed it with nine shapes of directive
/// and found this the one that got through. The URI is looked for anywhere in the directive now,
/// up to its semicolon, so a conditional, a deferred one and one broken over lines all count.
RegExp _drivers(String packages) => RegExp(
      '(import|export)\\s[^;]*[\'"]package:($packages)[/\'"][^;]*;'
      '|(import|export)\\s[^;]*[\'"]dart:(indexed_db|html)[\'"][^;]*;',
      dotAll: true,
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
