// The shell: one desk, five stacks of paper on it. The partner's strip sits at the top of every
// region so their state is legible everywhere, and the feeling corner sits at the bottom right of
// every region so a feeling is one gesture away from anywhere.
import 'package:flutter/material.dart';

import 'material/desk.dart';
import 'material/hands.dart';
import 'material/library.dart';
import 'material/light.dart';
import 'material/palette.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: DeskColour.day,
        colorScheme: const ColorScheme.light(
          surface: Color(0xFFF1ECDF),
          primary: Pen.ballpoint,
          secondary: Pen.graphite,
        ),
        textTheme: Typography.blackCupertino.apply(fontFamily: 'TeoHand'),
      ),
      home: const Light(condition: LightCondition.day, child: Shell()),
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

  static const _labels = [S.pulse, S.chat, S.us, S.moments, S.settings];

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      backgroundColor: DeskColour.day,
      body: Desk(
        child: SafeArea(
          child: Column(
            children: [
              PartnerStrip(
                partner: scope.partner,
                state: scope.partnerState,
                nowMs: scope.clock.now().millisecondsSinceEpoch,
              ),
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
              _Tabs(index: _index, labels: _labels, onPick: (i) => setState(() => _index = i)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The region strip: five tabs cut from index card, each with its label stamped on it.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.labels, required this.onPick});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final unread = scope.thread.unreadFor(scope.me);
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final card = lib?.stockVariants('index') ?? const <String>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(i),
                child: Padding(
                  padding: EdgeInsets.only(top: i == index ? 0 : 8, left: 2, right: 2),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      image: card.isEmpty
                          ? null
                          : DecorationImage(
                              image: AssetImage(paperAsset(card[i % card.length])),
                              fit: BoxFit.cover,
                              alignment: Alignment(-1 + 0.4 * i, 0.2),
                              opacity: i == index ? 1.0 : 0.82,
                            ),
                      color: card.isEmpty ? Paper.index.withValues(alpha: i == index ? 1 : 0.8) : null,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stamped(labels[i], size: i == index ? 12 : 11, colour: i == index ? Pen.stamp : Pen.margin),
                        if (i == 1 && unread > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text('$unread', style: Hands.margin(size: 12)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseStub extends StatelessWidget {
  const _PulseStub();

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.partnerState;
    if (p.signals.isEmpty) {
      return Center(child: Text(S.emptyPulse, style: Hands.margin(size: 16)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in p.signals.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 120, child: Stamped(s.signal, size: 11)),
              Expanded(child: Text('${s.value}', style: Hands.of(scope.partner, size: 17))),
              Text(s.declared ? 'set' : 'read', style: Hands.margin(size: 11)),
            ]),
          ),
      ],
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Stamped(label, size: 14));
}
