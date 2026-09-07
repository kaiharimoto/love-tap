// app/tool/host_daemon.dart — the other phone, for the clips that need two of them.
//
//   dart run tool/host_daemon.dart --out .../pair.json --transport tailscale \
//       --address 100.68.254.25 --proxy 127.0.0.1:1155 --seconds 90
//   dart run tool/host_daemon.dart --out .../pair.json --seed year --now 2026-09-03T19:40:00Z
//
// With --seed year the far phone carries the same seeded year the near one does, read off disk
// from the packed app/assets/seed/ (the same files the app bundles), so both spines hold the same
// fourteen thousand events with the same ids and seqs before they have exchanged a byte: pairing
// costs no pull, and every still is taken paired and connected on the real log rather than on a
// fixture. --now is the frozen clock the year is written against; what the far phone writes is
// stamped from it plus the seconds that have passed, the way the near phone's driven clock is.
//
// The propagation clip and the two-device frame need a device at the other end of the wire. This
// container has no Android phone — there is no /dev/kvm, so the emulator cannot boot — and no GTK,
// so there is no desktop build either. What there is is the app's own transport, spine and pairing,
// none of which need a screen. This runs them.
//
// So the phone at the far end here is headless: a real spine, the real HttpTransport in its host
// role, the real six-word pairing, writing real events that really cross. What it cannot do is be
// photographed, which is why 09_two_devices still cannot be taken in this session and is recorded
// as missing rather than faked. 08_state_propagating does not need the far phone to be visible —
// it needs a gesture on one device to become a sensation on the other, and that is exactly what
// this makes happen.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desk/feelings/registry.dart';
import 'package:desk/spine/seed_loader.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_sqlite.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/tailscale/tailscale_transport.dart';

/// The seed's files read off disk: the packed copy under app/assets/seed/, which is what the app
/// bundles, so the two phones read the very same bytes.
class FileSeedSource implements SeedSource {
  FileSeedSource(this.root);
  final String root;

  @override
  Future<String> loadString(String path) => File('$root/$path').readAsString();

  @override
  Future<Uint8List> loadBytes(String path) => File('$root/$path').readAsBytes();
}

String _arg(List<String> a, String name, String dflt) {
  final i = a.indexOf('--$name');
  return i >= 0 && i + 1 < a.length ? a[i + 1] : dflt;
}

Future<void> main(List<String> argv) async {
  final out = _arg(argv, 'out', 'pair.json');
  final kind = _arg(argv, 'transport', 'local');
  final address = _arg(argv, 'address', '');
  final proxy = _arg(argv, 'proxy', '');
  final port = int.parse(_arg(argv, 'port', kind == 'tailscale' ? '8443' : '8480'));
  final seconds = int.parse(_arg(argv, 'seconds', '120'));
  // The other phone loads the app from this one. That is how the two of them actually work —
  // the host serves the conversation and the page that reads it from one origin — and it is also
  // the only way a browser is allowed to fetch from here: a page served off a loopback file
  // server is a different origin from a host on the tailnet, and nothing in this transport sends
  // an Access-Control-Allow-Origin header, because on the phones there is nothing to allow.
  final pwa = _arg(argv, 'pwa', '');
  final seed = _arg(argv, 'seed', '');
  final nowArg = _arg(argv, 'now', '');
  final dir = await Directory.systemTemp.createTemp('host-daemon-');

  final spine = await Spine.open(NativeStore.openAt('${dir.path}/host.sqlite3'),
      const Identity(person: Person.noor, device: DeviceKind.android));

  // The clock the far phone stamps with: the frozen now the year is written against, moving
  // forward with the wall clock from the moment this started. Without it a message from the far
  // phone carried today's date into a thread whose "now" is two days earlier.
  final frozenAt = nowArg.isEmpty ? null : DateTime.parse(nowArg).toUtc();
  final startedAt = DateTime.now().toUtc();
  DateTime now() => frozenAt == null ? DateTime.now().toUtc() : frozenAt.add(DateTime.now().toUtc().difference(startedAt));

  if (seed == 'year') {
    final t0 = DateTime.now();
    final report = await SeedLoader(FileSeedSource(Directory.current.path)).load(spine);
    stdout.writeln('host-daemon: seeded year loaded: ${report?.events ?? 0} events, '
        '${report?.blobs ?? 0} blobs, ${report?.skipped.length ?? 0} skipped, '
        '${DateTime.now().difference(t0).inMilliseconds} ms');
  }

  // What this host will not take, when the harness asks it not to. Consumed one event at a time,
  // so `refuse 1` refuses exactly the next one the near phone pushes and everything after it
  // crosses normally.
  var refuseNext = 0;
  var refuseReason = '';
  String? refuses(Event e) {
    if (refuseNext <= 0) return null;
    refuseNext--;
    return refuseReason;
  }

  final Transport transport;
  if (kind == 'tailscale') {
    transport = tailscaleTransport(role: TransportRole.host, spine: spine,
        deviceId: 'android-capture', port: port, declaredAddress: address,
        userspaceProxy: proxy, pwaRoot: pwa.isEmpty ? null : pwa, refuses: refuses);
  } else {
    transport = LocalTransport(role: TransportRole.host, spine: spine,
        deviceId: 'android-capture', binding: LocalBinding(port: port),
        pwaRoot: pwa.isEmpty ? null : pwa, refuses: refuses);
  }
  await transport.start();

  // Everything the far side needs to find this one and prove who it is. Written as a file rather
  // than printed, so the capture harness reads it without parsing stdout. Minted again on request
  // (`pair` on the control file): a pairing code has a window, and a capture that runs for an
  // hour pairs a fresh near phone for every scene.
  Future<void> mint() async {
    final code = await (transport as dynamic).beginPairing();
    final tmp = File('$out.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert({
      'transport': kind,
      'base': kind == 'tailscale' ? 'http://$address:$port' : 'http://127.0.0.1:$port',
      'words': code.spoken,
      'device_id': 'android-capture',
      'person': 'noor',
      'seed': seed.isEmpty ? null : seed,
      'events': spine.length,
      'now': now().toIso8601String(),
      'started_at': startedAt.toIso8601String(),
      'minted_at': DateTime.now().toUtc().toIso8601String(),
    }));
    await tmp.rename(out);
  }

  await mint();
  stdout.writeln('host-daemon: up on ${kind == 'tailscale' ? address : '127.0.0.1'}:$port');
  stdout.writeln('host-daemon: six words written to $out');

  // A control file the harness drops a line into: `feeling hold 0.9`, `message ok on my way`.
  // One instruction per line, taken and removed. This is how a clip makes something happen on the
  // far phone at the exact frame it wants it.
  final control = File('$out.do');
  Timer? typingRepeat;
  // the built-ins and every feeling either of them has made, from the same log the near phone
  // reads them from: an authored feeling is sent the way a built-in is, because it is one
  final registry = FeelingRegistry(spine.all);
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (await control.exists()) {
      // Taken, then read. It used to read the file and then delete it, and a line written in
      // between — the harness appends one whenever it wants the far phone to do something — went
      // into the bin unread. That is how a feeling the scene had asked for never crossed, and the
      // scene waited thirty seconds for an arrival nobody had been told to send.
      final taken = File('$out.do.taken');
      await control.rename(taken.path);
      final lines = (await taken.readAsString()).trim().split('\n');
      await taken.delete();
      for (final line in lines) {
        final parts = line.trim().split(' ');
        if (parts.isEmpty || parts.first.isEmpty) continue;
        if (parts.first == 'feeling' && parts.length >= 2) {
          final f = registry.byId(parts[1]);
          if (f == null) {
            stdout.writeln('host-daemon: no feeling called ${parts[1]}');
            continue;
          }
          final e = await spine.append('feeling', {
            'feeling_id': f.id,
            'intensity': parts.length > 2 ? double.parse(parts[2]) : 0.85,
          }, at: now(), hostAssign: true);
          stdout.writeln('host-daemon: sent ${f.id} as ${e.id}');
        } else if (parts.first == 'state' && parts.length >= 3) {
          // What 08 is actually about: one of them says how they are, and the other one's phone
          // changes. The daemon could send a feeling and a message and not this, which is the one
          // thing the artifact is named after.
          final e = await spine.append('state_declared', {
            'signal': parts[1],
            'value': parts.skip(2).join(' '),
          }, at: now(), hostAssign: true);
          stdout.writeln('host-daemon: said ${parts[1]} is ${parts.skip(2).join(' ')} as ${e.id}');
        } else if (parts.first == 'message') {
          final e = await spine.append('message', {'text': parts.skip(1).join(' ')},
              at: now(), hostAssign: true);
          stdout.writeln('host-daemon: sent a message as ${e.id}');
        } else if (parts.first == 'read') {
          // The far person opens the thread: a read marker over everything they have, which is
          // what turns `sent` into `read` on the near phone — because they read it, not because
          // the seed says so.
          final upto = spine.ordered.isEmpty ? 0 : (spine.ordered.last.seq ?? 0);
          final e = await spine.append('read_marker', {'upto_seq': upto}, at: now(), hostAssign: true);
          stdout.writeln('host-daemon: read up to $upto as ${e.id}');
        } else if (parts.first == 'typing') {
          // Not an event and never stored: the frame the near phone shows as `noor writing…`.
          // While it is on the frame is sent again every three seconds, as the app's own composer
          // does while somebody keeps writing; the near phone lets a frame lapse after six.
          final on = parts.length < 2 || parts[1] != 'off';
          typingRepeat?.cancel();
          typingRepeat = null;
          Future<void> frame() => transport.sendEphemeral(Ephemeral(
              kind: 'typing', from: Person.noor, at: now().millisecondsSinceEpoch, data: {'on': on}));
          await frame();
          if (on) typingRepeat = Timer.periodic(const Duration(seconds: 3), (_) => frame());
          stdout.writeln('host-daemon: typing ${on ? 'on' : 'off'}');
        } else if (parts.first == 'refuse') {
          // The host says no to the next one, and says why. A refusal is one of the five states a
          // message can be in and the only one that cannot be produced from the other phone's own
          // composer — the near phone used to draw it by marking a row refused by hand, which is a
          // picture of the state rather than the state. This is the host actually refusing.
          refuseNext = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
          refuseReason = parts.length > 2
              ? parts.skip(2).join(' ')
              : 'this phone is on an older version and cannot read that';
          stdout.writeln('host-daemon: will refuse the next $refuseNext');
        } else if (parts.first == 'pair') {
          await mint();
          stdout.writeln('host-daemon: six words minted again');
        } else if (parts.first == 'stop') {
          stdout.writeln('host-daemon: asked to stop');
          typingRepeat?.cancel();
          await transport.stop();
          await spine.close();
          exit(0);
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
  stdout.writeln('host-daemon: ${spine.length} events written; stopping');
  await transport.stop();
  await spine.close();
}
