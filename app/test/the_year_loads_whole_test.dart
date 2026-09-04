// The seeded year arrives whole, or the test says which parts of it did not.
//
// The first critic pass found the thread was text only: the hundred and fifteen photographs, the
// fourteen videos and the fifty-four voice notes did not exist as files, so the loader dropped
// every media event and said so into a report nothing read. A year with no pictures in it is not
// the year the app is being judged on, and nothing in the suite noticed.
//
// This loads the real bundle the same way the app does and insists on the whole thing.
import 'dart:convert';

import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// How many of each type the year's own files say there are, read straight off them.
Future<Map<String, int>> _whatTheYearSays() async {
  final index = jsonDecode(await rootBundle.loadString('assets/seed/index.json'))
      as Map<String, dynamic>;
  final counts = <String, int>{};
  for (final month in (index['months'] as List).cast<String>()) {
    for (final line in const LineSplitter()
        .convert(await rootBundle.loadString('assets/seed/year/$month.jsonl'))) {
      if (line.trim().isEmpty) continue;
      final type = (jsonDecode(line) as Map)['type'] as String;
      counts[type] = (counts[type] ?? 0) + 1;
    }
  }
  return counts;
}

void main() {
  late SeedReport report;
  late Map<String, int> written;
  late Spine spine;

  /// Why there is nothing to check, or null when there is.
  String? absent;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    List months;
    try {
      final index = jsonDecode(await rootBundle.loadString('assets/seed/index.json'))
          as Map<String, dynamic>;
      months = (index['months'] as List?) ?? const [];
    } catch (_) {
      // a bundle packed without --seed=year has no year in it, and that is the point of the flag:
      // a build started without it has no way to load one
      absent = 'this bundle was packed without the seeded year '
          '(tools/pack_assets.py --seed=year puts it in)';
      return;
    }
    if (months.isEmpty) {
      absent = 'the bundle has a seed directory with no months in it';
      return;
    }
    written = await _whatTheYearSays();
    spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    report = (await SeedLoader(rootBundle).load(spine))!;
  });

  test('every line of the year is in the log', () async {
    if (absent != null) return markTestSkipped(absent!);
    final total = written.values.fold<int>(0, (a, b) => a + b);
    expect(report.skipped, isEmpty,
        reason: '${report.skipped.length} of $total lines did not make it into the log:\n'
            '${report.skipped.take(25).join('\n')}');
    expect(report.events, total);
    expect(spine.length, total);
  });

  test('the photographs, the videos and the voice notes are in it as files', () {
    if (absent != null) return markTestSkipped(absent!);
    final media = (written['photo'] ?? 0) + (written['video'] ?? 0) + (written['voice_note'] ?? 0);
    expect(media, greaterThan(150),
        reason: 'the year is meant to refer to a hundred and eighty-odd pieces of media');
    // a video carries two blobs: the file and the frame the thread shows before it plays
    final expected = media + (written['video'] ?? 0);
    expect(report.blobs, expected,
        reason: 'the log holds ${report.blobs} blobs for $media media events; every photograph, '
            'video and voice note in the year has to be a real file in the bundle');
  });

  test('the three anchors the artifacts are taken at resolved', () {
    if (absent != null) return markTestSkipped(absent!);
    expect(report.anchors.length, greaterThanOrEqualTo(3));
    for (final e in report.anchors.entries) {
      expect(spine.all.any((ev) => ev.id == e.value), isTrue,
          reason: 'the anchor ${e.key} points at ${e.value}, which is not in the log');
    }
  });
}
