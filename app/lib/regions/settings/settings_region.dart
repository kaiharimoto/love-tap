// Settings: pairing, what is allowed to interrupt, the feelings they have made, and the way out.
//
// Everything here is either a fact about the link or an event in the spine. Preferences that only
// concern this phone (which types may interrupt, quiet hours) live in the spine's meta, because
// they are not the couple's history — but nothing that either person *authored* is kept anywhere
// but the spine.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../capture/bus.dart';
import '../../feelings/builtins.dart';
import '../../flags.dart';
import '../../feelings/registry.dart';
import '../../feelings/sensation.dart';
import '../../material/hands.dart';
import '../../material/objects.dart';
import '../../material/palette.dart';
import '../../scope.dart';
import '../../transport/transport.dart';
import '../../voice/strings.dart';
import 'authoring.dart';
import 'notifications.dart';

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
  NotificationPrefs? _prefs;
  final Sensation _sensation = Sensation();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrefs();
      if (Flags.capture) CaptureBus.showWords = _showWords;
    });
  }

  Future<void> _loadPrefs() async {
    final p = await NotificationPrefs.load(AppScope.of(context).spine);
    if (mounted) setState(() => _prefs = p);
  }

  /// Capture mode: put the six words on screen without a thumb on the button.
  Future<void> _showWords() async {
    final c = await AppScope.of(context).transport.beginPairing();
    if (mounted) setState(() => _code = c);
  }

  @override
  void dispose() {
    if (Flags.capture) CaptureBus.showWords = null;
    _address.dispose();
    _words.dispose();
    _sensation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = scope.transport;
    final link = scope.link;
    final registry = FeelingRegistry(scope.spine.all);
    final authored = registry.all.where((f) => !f.builtIn).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 96),
      children: [
        const Stamped('the two phones', size: 11),
        const SizedBox(height: 6),
        _Pairing(
          transport: t,
          link: link,
          code: _code,
          address: _address,
          words: _words,
          result: _result,
          onShow: () async {
            final c = await t.beginPairing();
            setState(() => _code = c);
          },
          onPair: () async {
            try {
              final p = await t.completePairing(_address.text.trim(), _words.text);
              setState(() => _result = 'paired with ${p.hostPerson.name}');
              scope.sync.kick();
            } on TransportException catch (e) {
              setState(() => _result = e.status == 403 ? "those aren't the words. try again." : S.hostDown);
            }
          },
          onUnpair: () async {
            await t.unpair();
            setState(() => _result = 'unpaired. the other phone will need the words again.');
          },
        ),
        const SizedBox(height: 22),
        const Stamped('what may interrupt', size: 11),
        const SizedBox(height: 6),
        if (!scope.ambient.allowed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () async {
                await scope.ambient.ask();
                if (mounted) setState(() {});
              },
              child: Text('let it interrupt you', style: Hands.margin(size: 16)),
            ),
          ),
        if (_prefs != null)
          NotificationSettings(
            prefs: _prefs!,
            onChanged: (p) async {
              await p.save(scope.spine);
              setState(() => _prefs = p);
            },
          ),
        const SizedBox(height: 22),
        Row(children: [
          const Stamped('feelings you made', size: 11),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final made = await AuthoringSheet.open(context, registry: registry, me: scope.me);
              if (made == null) return;
              await scope.emit('feeling_authored', made);
            },
            child: Text('make one', style: Hands.margin(size: 14)),
          ),
        ]),
        const SizedBox(height: 8),
        if (authored.isEmpty)
          Text(S.emptyFeelings, style: Hands.margin(size: 15))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in authored)
                GestureDetector(
                  onTap: () => _sensation.play(f, intensity: 0.8),
                  onLongPress: () => scope.emit('feeling_authored', {
                    'feeling_id': f.id,
                    'name': f.name,
                    'family': f.family.label,
                    'colour': f.colour,
                    'object_asset': f.object,
                    'haptic': f.haptic,
                    'sound': f.sound,
                    'retired': !f.retired,
                  }),
                  child: Column(
                    children: [
                      Opacity(opacity: f.retired ? 0.4 : 1, child: FeelingObject(feeling: f, size: 64, intensity: 0.7)),
                      Text(f.name, style: Hands.margin(size: 12)),
                      Text(f.retired ? 'put away' : 'by ${f.authoredBy}', style: Hands.margin(size: 10)),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: 22),
        const Stamped('the two of you', size: 11),
        const SizedBox(height: 6),
        _Fact('this phone', '${scope.me.name} · ${t.role.name} · ${t.name}'),
        _Fact('their phone', scope.partner.name),
        _Fact('history', '${scope.spine.length} events, ${scope.spine.pending.length} waiting to send'),
        _Fact('feelings', '${registry.active.length} to send, ${authored.length} made here'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _export,
          child: Text('write the whole history out', style: Hands.margin(size: 15)),
        ),
        const SizedBox(height: 10),
        Text('everything either of you wrote is in one log on both phones. this copies it out.',
            style: Hands.margin(size: 12)),
      ],
    );
  }

  Future<void> _export() async {
    final scope = AppScope.of(context);
    final lines = scope.spine.all.map((e) => jsonEncode(e.toJson())).join('\n');
    unawaited(scope.spine.setMeta('export.last', DateTime.now().toUtc().toIso8601String()));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF1ECDF),
        content: SizedBox(
          width: 420,
          child: SelectableText(
            lines.length > 4000 ? '${lines.substring(0, 4000)}\n…' : lines,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('close', style: Hands.margin(size: 15)))],
      ),
    );
  }
}

class _Pairing extends StatelessWidget {
  const _Pairing({
    required this.transport,
    required this.link,
    required this.code,
    required this.address,
    required this.words,
    required this.result,
    required this.onShow,
    required this.onPair,
    required this.onUnpair,
  });

  final Transport transport;
  final TransportStatus link;
  final PairingCode? code;
  final TextEditingController address;
  final TextEditingController words;
  final String? result;
  final VoidCallback onShow;
  final VoidCallback onPair;
  final VoidCallback onUnpair;

  @override
  Widget build(BuildContext context) {
    final paired = transport.pairing;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      color: const Color(0xFFF3EEE3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (paired != null) ...[
            Text('two phones, linked ${_ago(paired.pairedAt)}', style: Hands.teo(size: 17)),
            const SizedBox(height: 4),
            _Fact(paired.hostPerson.name, '${paired.hostId} · holds the log'),
            _Fact(paired.clientPerson.name, paired.clientId),
          ] else
            Text(S.notPaired, style: Hands.teo(size: 17)),
          _Fact('link', '${link.state.name}${link.address != null ? ' · ${link.address}' : ''}'),
          const SizedBox(height: 10),
          if (transport.role == TransportRole.host) ...[
            GestureDetector(onTap: onShow, child: Text('read six words to them', style: Hands.margin(size: 15))),
            if (code != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SelectableText(code!.spoken, style: Hands.stamp(size: 20, spacing: 1.2)),
              ),
          ] else ...[
            TextField(controller: address, style: Hands.teo(size: 16), decoration: _line('their address')),
            TextField(controller: words, style: Hands.teo(size: 16), decoration: _line('the six words')),
            const SizedBox(height: 8),
            GestureDetector(onTap: onPair, child: Text('pair', style: Hands.margin(size: 15))),
          ],
          if (paired != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: onUnpair,
                child: Text('replace one of the phones', style: Hands.margin(size: 14)),
              ),
            ),
          if (result != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(result!, style: Hands.margin(size: 14))),
        ],
      ),
    );
  }

  static InputDecoration _line(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: Hands.margin(size: 15),
        border: const UnderlineInputBorder(borderSide: BorderSide(color: Pen.margin)),
      );

  static String _ago(DateTime when) {
    final d = DateTime.now().toUtc().difference(when);
    if (d.inDays > 1) return '${d.inDays} days ago';
    if (d.inHours > 1) return '${d.inHours} hours ago';
    return 'just now';
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Stamped(label, size: 9, colour: Pen.margin)),
            Expanded(child: Text(value, style: Hands.margin(size: 14))),
          ],
        ),
      );
}
