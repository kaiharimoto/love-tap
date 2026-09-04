// app/tool/host_daemon.dart — the other phone, for the clips that need two of them.
//
//   dart run tool/host_daemon.dart --out .../pair.json --transport tailscale \
//       --address 100.68.254.25 --proxy 127.0.0.1:1155 --seconds 90
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
import 'dart:convert';
import 'dart:io';

import 'package:desk/feelings/builtins.dart';
import 'package:desk/spine/spine.dart';
import 'package:desk/spine/store/store_sqlite.dart';
import 'package:desk/transport/local/local_transport.dart';
import 'package:desk/transport/tailscale/tailscale_transport.dart';

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
  final dir = await Directory.systemTemp.createTemp('host-daemon-');

  final spine = await Spine.open(NativeStore.openAt('${dir.path}/host.sqlite3'),
      const Identity(person: Person.noor, device: DeviceKind.android));

  final Transport transport;
  if (kind == 'tailscale') {
    transport = tailscaleTransport(role: TransportRole.host, spine: spine,
        deviceId: 'android-capture', port: port, declaredAddress: address,
        userspaceProxy: proxy, pwaRoot: pwa.isEmpty ? null : pwa);
  } else {
    transport = LocalTransport(role: TransportRole.host, spine: spine,
        deviceId: 'android-capture', binding: LocalBinding(port: port),
        pwaRoot: pwa.isEmpty ? null : pwa);
  }
  await transport.start();
  final code = await (transport as dynamic).beginPairing();

  // Everything the far side needs to find this one and prove who it is. Written as a file rather
  // than printed, so the capture harness reads it without parsing stdout.
  await File(out).writeAsString(const JsonEncoder.withIndent(' ').convert({
    'transport': kind,
    'base': kind == 'tailscale' ? 'http://$address:$port' : 'http://127.0.0.1:$port',
    'words': code.spoken,
    'device_id': 'android-capture',
    'person': 'noor',
    'started_at': DateTime.now().toUtc().toIso8601String(),
  }));
  stdout.writeln('host-daemon: up on ${kind == 'tailscale' ? address : '127.0.0.1'}:$port');
  stdout.writeln('host-daemon: six words written to $out');

  // A control file the harness drops a line into: `feeling hold 0.9`, `message ok on my way`.
  // One instruction per line, taken and removed. This is how a clip makes something happen on the
  // far phone at the exact frame it wants it.
  final control = File('$out.do');
  final feelings = {for (final f in kBuiltInFeelings) f.id: f};
  final deadline = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(deadline)) {
    if (await control.exists()) {
      final lines = (await control.readAsString()).trim().split('\n');
      await control.delete();
      for (final line in lines) {
        final parts = line.trim().split(' ');
        if (parts.isEmpty || parts.first.isEmpty) continue;
        if (parts.first == 'feeling' && parts.length >= 2) {
          final f = feelings[parts[1]];
          if (f == null) continue;
          final e = await spine.append('feeling', {
            'feeling_id': f.id,
            'intensity': parts.length > 2 ? double.parse(parts[2]) : 0.85,
          }, at: DateTime.now(), hostAssign: true);
          stdout.writeln('host-daemon: sent ${f.id} as ${e.id}');
        } else if (parts.first == 'state' && parts.length >= 3) {
          // What 08 is actually about: one of them says how they are, and the other one's phone
          // changes. The daemon could send a feeling and a message and not this, which is the one
          // thing the artifact is named after.
          final e = await spine.append('state_declared', {
            'signal': parts[1],
            'value': parts.skip(2).join(' '),
          }, at: DateTime.now(), hostAssign: true);
          stdout.writeln('host-daemon: said ${parts[1]} is ${parts.skip(2).join(' ')} as ${e.id}');
        } else if (parts.first == 'message') {
          final e = await spine.append('message', {'text': parts.skip(1).join(' ')},
              at: DateTime.now(), hostAssign: true);
          stdout.writeln('host-daemon: sent a message as ${e.id}');
        } else if (parts.first == 'stop') {
          stdout.writeln('host-daemon: asked to stop');
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
