// Settings (unstyled for now): pairing and the link. The rest arrives in step 09.
import 'package:flutter/material.dart';

import '../../scope.dart';
import '../../transport/transport.dart';
import '../../voice/strings.dart';

class SettingsRegion extends StatefulWidget {
  const SettingsRegion({super.key});

  @override
  State<SettingsRegion> createState() => _SettingsRegionState();
}

class _SettingsRegionState extends State<SettingsRegion> {
  PairingCode? _code;
  final _address = TextEditingController(text: 'http://127.0.0.1:8480');
  final _words = TextEditingController();
  String? _result;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = scope.transport;
    final link = scope.link;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${scope.me.name} · ${t.role.name} · ${t.name}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('link: ${link.state.name}${link.address != null ? ' · ${link.address}' : ''}${link.lastError != null ? ' · ${link.lastError}' : ''}'),
        Text('cursor ${scope.spine.cursor} · pending ${scope.spine.pending.length} · events ${scope.spine.length}'),
        const Divider(height: 32),
        if (t.pairing != null)
          Text('paired with ${t.pairing!.hostId == t.deviceId ? t.pairing!.clientId : t.pairing!.hostId} since ${t.pairing!.pairedAt.toLocal()}')
        else
          const Text(S.notPaired),
        const SizedBox(height: 12),
        if (t.role == TransportRole.host) ...[
          FilledButton(
            onPressed: () async {
              final c = await t.beginPairing();
              setState(() => _code = c);
            },
            child: const Text('show the six words'),
          ),
          if (_code != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(_code!.spoken, style: Theme.of(context).textTheme.headlineSmall),
            ),
        ] else ...[
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'the other phone')),
          TextField(controller: _words, decoration: const InputDecoration(labelText: 'the six words')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              try {
                final p = await t.completePairing(_address.text.trim(), _words.text);
                setState(() => _result = 'paired with ${p.hostPerson.name}');
                scope.sync.kick();
              } on TransportException catch (e) {
                setState(() => _result = e.status == 403 ? "those aren't the words. try again." : S.hostDown);
              }
            },
            child: const Text('pair'),
          ),
          if (_result != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_result!)),
        ],
        const Divider(height: 32),
        Text('report', style: Theme.of(context).textTheme.titleSmall),
        Text(scope.sync.report().toString(), style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
