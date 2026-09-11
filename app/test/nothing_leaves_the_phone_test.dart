// The log does not leave this phone, and a release is signed with a real key or says it is not.
//
// Two things that only exist in the Android project and cannot be photographed, so they are read
// here instead.
//
// Android backs an app's files up to the owner's Google account by default. The log is one of the
// two copies of a conversation between two people and it is the only one on this handset; a
// default that copies it to a third machine neither of them chose is the opposite of what the
// whole tailnet arrangement is for. It has to be off in three places, because Android changed the
// mechanism twice and reads a different one depending on the version.
//
// And a release APK signed with the debug key installs on a phone and is not a release: a build
// signed with a real key cannot replace it without uninstalling first, which takes the log with
// it. That is a thing to find out before two people have a year in it, so the build says so.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();

  test('nothing is backed up off the phone', () {
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/nothing_leaves"'));

    final rules = File('android/app/src/main/res/xml/nothing_leaves.xml').readAsStringSync();
    // Both halves: the cloud backup and the phone-to-phone transfer.
    expect(rules, contains('<cloud-backup>'));
    expect(rules, contains('<device-transfer>'));
    for (final half in rules.split('<device-transfer>')) {
      for (final domain in ['root', 'file', 'database', 'sharedpref']) {
        expect(half, contains('<exclude domain="$domain" />'),
            reason: 'a backup could still carry $domain');
      }
    }
    expect(rules, isNot(contains('<include')), reason: 'an include is a thing that leaves');
  });

  test('and nothing speaks cleartext', () {
    // The conversation is served over TLS to a tailnet address and nowhere else.
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });

  test('a release is signed with a real key, or the build says it is not', () {
    // No key, no password, no keystore path in anything committed — the four names appear only as
    // the properties read out of a file this repository does not have.
    expect(gradle, contains('key.properties'));
    expect(gradle, contains('signedForReal'));
    expect(gradle, contains('logger.lifecycle'),
        reason: 'a release signed with the debug key has to say so at build time');
    final ignored = File('android/.gitignore').readAsStringSync();
    for (final pattern in ['key.properties', '.jks', '.keystore']) {
      expect(ignored, contains(pattern), reason: '$pattern is not ignored');
    }
    // And the template's TODOs are gone: they are the ones that say to do this.
    expect(gradle, isNot(contains('TODO')));
  });

  test('no key material is committed anywhere under the app', () {
    final bad = <String>[];
    for (final f in Directory('android').listSync(recursive: true).whereType<File>()) {
      final name = f.path;
      if (name.endsWith('.jks') || name.endsWith('.keystore') || name.endsWith('key.properties')) {
        bad.add(name);
      }
    }
    expect(bad, isEmpty, reason: 'these are in the tree: ${bad.join(', ')}');
  });
}
