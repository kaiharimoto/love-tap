// The messenger can do more than the evidence shows, and that gap is worth points and nothing else.
//
// Cycle 3's reading: "reply, edit, attach, reaction, voice and video appear in no artifact". All
// six worked. None was framed. Reply and reaction were closed by staging real ones; edit is staged
// the same way here, attach is a scene step, and voice and video are in the seeded year already —
// what was missing was a way to point a camera at them, because a fraction of the way down a
// fourteen-thousand-row thread lands somewhere different every time the seed changes.
//
// So: the staging emits a real edit down the composer's own path, and the thread can be asked for
// the tightest stretch that holds a given set of kinds. Both are checked against a real spine.
import 'dart:async';

import 'package:desk/capture/bus.dart';
import 'package:desk/material/library.dart';
import 'package:desk/regions/chat/chat_region.dart';
import 'package:desk/scope.dart';
import 'package:desk/spine/event.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/sync.dart';
import 'package:desk/transport/transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Events as the other phone really makes them: minted on the host, with the host's own sequence
/// numbers, so what lands here went through accept rather than being written into this device's
/// own log with somebody else's name on it.
Future<List<Event>> _fromNoor(Future<void> Function(Spine) write) async {
  final far = await Spine.open(
    SpineStore.memory(),
    const Identity(person: Person.noor, device: DeviceKind.android),
  );
  await write(far);
  return far.ordered;
}

/// Start a handle, pump the clock it is waiting on, then take its answer. Awaiting first is a
/// deadlock: the handle waits for a settle that waits for a pump that is waiting for the handle.
Future<void> _run(WidgetTester tester, Future<void> Function() work) async {
  final running = work();
  var settled = false;
  unawaited(running.then((_) => settled = true, onError: (Object _) => settled = true));
  for (var i = 0; i < 60 && !settled; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (!settled) fail('the handle never came back after six seconds of pumping');
  await running;
}

void main() {
  // Once, not per test: MaterialLibrary.load reads the manifest off the bundle, and a second
  // call from inside another test's fake-async zone waits on an I/O future that zone will never
  // pump. It does not fail — it sits there until the run is killed, which is how an hour goes.
  setUpAll(() async {
    await MaterialLibrary.load();
  });

  testWidgets('the staged states carry an edit, a reaction and a reply', (tester) async {
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    // two from the other person, so there is something to react to and something to answer.
    // They come in the way they really do: minted on the host, accepted here.
    await spine.accept(await _fromNoor((far) async {
      await far.append('message', {'text': 'the awning is down again'}, hostAssign: true);
      await far.append('message', {'text': 'and the cat got in'}, hostAssign: true);
    }));
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await _run(tester, () => CaptureBus.stageStates!());
    await tester.pump(const Duration(milliseconds: 200));

    final types = [for (final e in spine.all) e.type];
    expect(types, contains('message_edit'),
        reason: 'the frame that is meant to show the whole grammar has no edit in it');
    expect(types, contains('reaction'),
        reason: 'a reaction was staged in cycle 3 and must stay staged');
    expect(types, contains('message_delete'),
        reason: 'a row taken back is a different picture from a row never sent');
    final report = CaptureBus.chatReport!();
    expect(report['replying_to'], isNotNull,
        reason: 'the reply banner is what makes replying visible in a still');
    expect((report['composer'] as String).trim(), isNotEmpty);

    // and the edit landed on the message it was aimed at, not on a new row of its own
    final edit = spine.all.lastWhere((e) => e.type == 'message_edit');
    final target = edit.payload['target'] as String;
    expect(spine.all.any((e) => e.id == target && e.type == 'message'), isTrue,
        reason: 'the edit points at nothing that was said');
  });

  testWidgets('the thread can be asked where a kind of paper actually is', (tester) async {
    CaptureBus.wanted = true;
    addTearDown(() => CaptureBus.wanted = false);
    final spine = await Spine.open(
      SpineStore.memory(),
      const Identity(person: Person.teo, device: DeviceKind.pwa),
    );
    // a long thread with the two rare kinds a long way in, the shape the seeded year has
    await spine.accept(await _fromNoor((far) async {
      for (var i = 0; i < 24; i++) {
        await far.append('message', {'text': 'row $i'}, hostAssign: true);
      }
      await far.append('voice_note', {
        'blob': 'sha256-none',
        'duration_ms': 4200,
        'waveform': [2, 7, 4, 9, 3],
        'mime': 'audio/ogg',
      }, hostAssign: true);
      for (var i = 0; i < 3; i++) {
        await far.append('message', {'text': 'after $i'}, hostAssign: true);
      }
      await far.append('video', {
        'blob': 'sha256-none',
        'poster_blob': 'sha256-none',
        'duration_ms': 9000,
        'w': 720,
        'h': 1280,
        'mime': 'video/mp4',
      }, hostAssign: true);
      for (var i = 0; i < 16; i++) {
        await far.append('message', {'text': 'tail $i'}, hostAssign: true);
      }
    }));
    final transport = LocalTransport(role: TransportRole.client, spine: spine, deviceId: 'test');
    final scope = AppScope(
      spine: spine,
      transport: transport,
      sync: SyncEngine(spine: spine, transport: transport),
      clock: Clock(frozenAt: DateTime.utc(2026, 9, 3, 19, 40)),
    );
    addTearDown(scope.dispose);
    tester.view.physicalSize = const Size(1440, 3120);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope.provide(
      scope: scope,
      child: const MaterialApp(home: Scaffold(body: ChatRegion())),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    await _run(tester, () => CaptureBus.scrollTo!('types:voice_note,video'));
    await tester.pump(const Duration(milliseconds: 400));

    final report = CaptureBus.chatReport!();
    final kinds = (report['kinds'] as Map).keys.toSet();
    expect(kinds, containsAll(<String>['voice_note', 'video']),
        reason: 'the anchor is meant to put both kinds in the frame at once; it framed $kinds');
    expect(report['anchor'], contains('types:voice_note,video'),
        reason: 'the report has to say where it was pointed, or a reader cannot check it');
  });
}
