// Where a test writes its record, which is not into the evidence unless somebody asked.
//
// Two tests write files the evidence set ships — reliability.json and coldstart.json — and they
// wrote them on every run. A completeness critic ran `flutter test` once to check a rule and had to
// restore both with `git checkout` afterwards, and said so in its own report: the mutation is a
// finding. It is worse than untidy. The capture writes those files at the top of its run, and
// anything that runs the suite afterwards replaces them with a record of a different run, so the
// set that ships says it was written by a capture that did not write it.
//
// The tests still run and still assert. They write into the evidence only when the capture asks,
// and the capture is the only thing that asks.
import 'dart:io';

/// True when this run is the capture's own, which is the only run whose numbers belong in the set.
bool get theCaptureAskedForThis =>
    Platform.environment['DESK_WRITE_EVIDENCE'] == '1';

/// Where a record goes: into the evidence when the capture asked, and into a scratch file beside
/// the build when it did not, so the assertions still have something to read back.
File recordAt(String evidencePath) {
  if (theCaptureAskedForThis) return File(evidencePath);
  final dir = Directory('${Directory.systemTemp.path}/desk-records');
  dir.createSync(recursive: true);
  return File('${dir.path}/${evidencePath.split('/').last}');
}
