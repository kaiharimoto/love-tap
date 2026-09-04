// The shell: one desk, five stacks of paper on it. The partner's strip sits at the top of every
// region so their state is legible everywhere, and the feeling corner sits at the bottom right of
// every region so a feeling is one gesture away from anywhere.
import 'dart:async';

import 'package:flutter/material.dart';

import 'capture/bus.dart';
import 'flags.dart';
import 'material/desk.dart';
import 'material/hands.dart';
import 'material/library.dart';
import 'material/light.dart';
import 'material/palette.dart';
import 'feelings/builtins.dart';
import 'feelings/corner.dart';
import 'feelings/registry.dart';
import 'feelings/sensation.dart';
import 'regions/chat/chat_region.dart';
import 'regions/moments/moments_region.dart';
import 'regions/pulse/pulse_region.dart';
import 'regions/settings/settings_region.dart';
import 'regions/us/us_region.dart';
import 'scope.dart';
import 'setup/checklist.dart';
import 'transport/transport.dart';
import 'setup/platform.dart';
import 'setup/setup_region.dart';
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
        scaffoldBackgroundColor: Flags.dusk ? DeskColour.dusk : DeskColour.day,
        colorScheme: const ColorScheme.light(
          surface: Color(0xFFF1ECDF),
          primary: Pen.ballpoint,
          secondary: Pen.graphite,
        ),
        textTheme: Typography.blackCupertino.apply(fontFamily: 'TeoHand'),
      ),
      home: Light(
        condition: Flags.dusk ? LightCondition.dusk : LightCondition.day,
        child: const Shell(),
      ),
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

  /// Until the two phones are actually set up, the list of what is left is the first thing shown.
  /// Any tab still works — nothing is locked — and the list comes back from Settings.
  bool _showSetup = true;
  PhoneFacts? _phone;
  final Sensation _sensation = Sensation();

  static const _labels = [S.pulse, S.chat, S.us, S.moments, S.settings];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readPhone());
    if (!Flags.capture) return;
    CaptureBus.regionIndex = _index;
    CaptureBus.goToRegion = _go;
    CaptureBus.sendFeeling = (id, intensity) async {
      final scope = AppScope.of(context);
      final f = FeelingRegistry(scope.spine.all).byId(id);
      if (f == null) return;
      // The handle returns as soon as the feeling is in the log, and leaves the sensation running.
      // Awaiting the whole thing would mean the harness only ever started taking frames after the
      // landing had finished, which is how a clip of a feeling arriving becomes a clip of a desk.
      await scope.emit('feeling', {
        'feeling_id': f.id,
        'intensity': double.parse(intensity.toStringAsFixed(2)),
      });
      unawaited(_sensation.play(f, intensity: intensity));
    };
  }

  @override
  void dispose() {
    if (Flags.capture) CaptureBus.clear();
    _sensation.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() {
      _index = i;
      _showSetup = false;
    });
    CaptureBus.regionIndex = i;
  }

  Future<void> _readPhone() async {
    final f = await PhoneFacts.read();
    if (mounted) setState(() => _phone = f);
  }

  /// The facts the list watches for, read fresh every time it is drawn.
  SetupFacts _setupFacts(AppScope scope) => factsFrom(
        platform: scope.transport.role == TransportRole.host ? 'android' : 'pwa',
        spine: scope.spine,
        link: scope.link,
        pairing: scope.transport.pairing,
        notificationsAllowed: _phone?.notificationsAllowed ?? false,
        installedToHome: _phone?.installedToHome ?? false,
      );

  Future<void> _send(Feeling f, double intensity) async {
    final scope = AppScope.of(context);
    await scope.emit('feeling', {'feeling_id': f.id, 'intensity': double.parse(intensity.toStringAsFixed(2))});
    await _sensation.play(f, intensity: intensity);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final facts = _setupFacts(scope);
    final platform = scope.transport.role == TransportRole.host ? 'android' : 'pwa';
    final setup = _showSetup && !settled(stepsFor(platform), facts) ? facts : null;
    return Scaffold(
      backgroundColor: Flags.dusk ? DeskColour.dusk : DeskColour.day,
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
                child: Stack(
                  children: [
                    if (setup != null)
                      SetupSheet(
                        platform: scope.transport.role == TransportRole.host ? 'android' : 'pwa',
                        facts: setup,
                        hostAddress: scope.link.address,
                      )
                    else
                      IndexedStack(
                        index: _index,
                        children: const [
                          PulseRegion(),
                          ChatRegion(),
                          UsRegion(),
                          MomentsRegion(),
                          SettingsRegion(),
                        ],
                      ),
                    // one gesture from any region
                    FeelingCorner(
                      registry: FeelingRegistry(scope.spine.all),
                      onSend: _send,
                      onPreview: (f, i) => _sensation.play(f, intensity: i, sound: true),
                    ),
                  ],
                ),
              ),
              _Tabs(index: _index, labels: _labels, onPick: _go),
            ],
          ),
        ),
      ),
    );
  }
}

/// A corner folded down on the card: something is waiting, and that is all it says.
class _TurnedCorner extends StatelessWidget {
  const _TurnedCorner();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(15, 15), painter: _CornerPainter());
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // the flap: the back of the card, catching the light from the same direction as everything else
    final flap = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(flap, Paint()..color = Paper.aged);
    canvas.drawPath(
      flap,
      Paint()
        ..color = Shadow.warm.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    // and the small shadow it drops on the card underneath it
    canvas.drawLine(
      Offset(0, 0),
      Offset(w, h),
      Paint()
        ..color = Shadow.warm.withValues(alpha: 0.22)
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
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
    // Something unread turns the corner of the card down. It is not a count and it never becomes
    // one: a number that goes up while you are not looking is the whole mechanism the brief
    // forbids, and a folded corner says the same true thing without keeping score.
    final waiting = scope.thread.unreadFor(scope.me) > 0;
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Stamped(labels[i], size: i == index ? 12 : 11, colour: i == index ? Pen.stamp : Pen.margin),
                        if (i == 1 && waiting)
                          const Positioned(top: 0, right: 0, child: _TurnedCorner()),
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
