// The shell: five regions over one spine. Deliberately unstyled until the material system
// exists (build order step 06).
import 'package:flutter/material.dart';

import 'regions/chat/chat_region.dart';
import 'regions/settings/settings_region.dart';
import 'scope.dart';
import 'voice/strings.dart';

class DeskApp extends StatelessWidget {
  const DeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3A3A3C)),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final unread = scope.thread.unreadFor(scope.me);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _PartnerStrip(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  _PulseStub(),
                  ChatRegion(),
                  _Stub(S.us),
                  _Stub(S.moments),
                  SettingsRegion(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.circle_outlined), label: S.pulse),
          NavigationDestination(
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.notes)),
            label: S.chat,
          ),
          const NavigationDestination(icon: Icon(Icons.checklist), label: S.us),
          const NavigationDestination(icon: Icon(Icons.photo_library_outlined), label: S.moments),
          const NavigationDestination(icon: Icon(Icons.tune), label: S.settings),
        ],
      ),
    );
  }
}

/// The partner's state on every region (unstyled: one line of text for now).
class _PartnerStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.partnerState;
    final bits = <String>[
      scope.partner.name,
      if (p.mood != null) p.mood!,
      p.availability,
      if (p.statusLine != null) '"${p.statusLine}"',
      'need ${p.need}',
      'energy ${p.energy}',
      if (p.place != null) p.place!,
      if (p.battery != null) 'battery ${p.battery}%',
      scope.link.state.name,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(bits.join(' · '), style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _PulseStub extends StatelessWidget {
  const _PulseStub();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.partnerState;
    if (p.signals.isEmpty) return const Center(child: Text(S.emptyPulse));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in p.signals.values)
          ListTile(dense: true, title: Text(s.signal), subtitle: Text('${s.value}'), trailing: Text(s.declared ? 'declared' : 'passive')),
      ],
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}
