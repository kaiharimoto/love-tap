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
import 'material/paper.dart';
import 'material/motion.dart';
import 'material/palette.dart';
import 'feelings/builtins.dart';
import 'feelings/corner.dart';
import 'feelings/landing.dart';
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

class _NoBars extends MaterialScrollBehavior {
  const _NoBars();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  /// And no blue glow at the end of a list either: paper stops because it has run out.
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

class DeskApp extends StatelessWidget {
  const DeskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      debugShowCheckedModeBanner: false,
      // No scrollbars. Every list in the app is paper being moved on a desk, and a grey capsule
      // sliding down the right-hand edge of it is the framework's furniture, not the app's — two
      // of them were visible on the settings artifact at once, one inside the pairing card and
      // one down the side of the sheet of notification settings.
      scrollBehavior: const _NoBars(),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Flags.dusk ? DeskColour.dusk : DeskColour.day,
        colorScheme: ColorScheme.light(
          // Every surface in this app is a piece of paper that was rendered, and none of them is
          // this one. A stock Material surface showing through is a bug, so it is the colour of
          // the desk: it reads as a widget floating on wood, which is what it is, rather than as
          // a convincing enough sheet to survive a look.
          surface: Flags.dusk ? DeskColour.dusk : DeskColour.day,
          primary: Pen.ballpoint,
          secondary: Pen.graphite,
        ),
        textTheme: Typography.blackCupertino.apply(fontFamily: 'TeoHand'),
      ),
      // dusk only when the dusk half of the library is actually baked; see MaterialLibrary.hasDusk
      home: Light(
        condition: Flags.dusk && MaterialLibrary.loaded && MaterialLibrary.instance.hasDusk
            ? LightCondition.dusk
            : LightCondition.day,
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

  /// Everything that lands on this phone, whichever side let go of it.
  final StreamController<Arrival> _arrivals = StreamController<Arrival>.broadcast();

  static const _labels = [S.pulse, S.chat, S.us, S.moments, S.settings];

  StreamSubscription<(String, double)>? _landings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readPhone();
      // Something they sent lands here the same way something you sent does. This is the whole
      // point of the app, so it happens whichever region is open rather than only in Chat.
      final scope = AppScope.of(context);
      _landings = scope.landed.listen((pair) {
        final f = scope.feelings.byId(pair.$1);
        if (f == null || !mounted) return;
        _arrivals.add(Arrival(feeling: f, intensity: pair.$2, mine: false));
        unawaited(_sensation.play(f, intensity: pair.$2));
      });
    });
    if (!Flags.capture) return;
    CaptureBus.regionIndex = _index;
    CaptureBus.goToRegion = _go;
    CaptureBus.sendFeeling = (id, intensity) async {
      final scope = AppScope.of(context);
      final f = scope.feelings.byId(id);
      if (f == null) return;
      // The handle returns as soon as the feeling is in the log, and leaves the sensation running.
      // Awaiting the whole thing would mean the harness only ever started taking frames after the
      // landing had finished, which is how a clip of a feeling arriving becomes a clip of a desk.
      await scope.emit('feeling', {
        'feeling_id': f.id,
        'intensity': double.parse(intensity.toStringAsFixed(2)),
      });
      _arrivals.add(Arrival(feeling: f, intensity: intensity, mine: true));
      unawaited(_sensation.play(f, intensity: intensity));
    };
  }

  @override
  void dispose() {
    if (Flags.capture) CaptureBus.clear();
    _landings?.cancel();
    _arrivals.close();
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
    _arrivals.add(Arrival(feeling: f, intensity: intensity, mine: true));
    await _sensation.play(f, intensity: intensity);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final facts = _setupFacts(scope);
    final platform = scope.transport.role == TransportRole.host ? 'android' : 'pwa';
    final setup = _showSetup && !settled(stepsFor(platform), facts) ? facts : null;
    if (Flags.capture) CaptureBus.setupShowing = setup != null;
    return Scaffold(
      backgroundColor: Flags.dusk ? DeskColour.dusk : DeskColour.day,
      body: Desk(
        child: LandingStage(
          arrivals: _arrivals.stream,
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
                      // Every region keeps its state and its scroll, so they are all built and
                      // one is shown — but showing one by cutting to it is a hard edit: half the
                      // brightness of the screen changes between two frames, which reads as a
                      // splice rather than as a hand moving between two piles of paper. The paper
                      // underneath does not move; what is on it is exchanged.
                      Turning(
                        child: KeyedSubtree(
                          key: ValueKey(_index),
                          child: IndexedStack(
                            index: _index,
                            children: const [
                              PulseRegion(),
                              ChatRegion(),
                              UsRegion(),
                              MomentsRegion(),
                              SettingsRegion(),
                            ],
                          ),
                        ),
                      ),
                    // one gesture from any region
                    FeelingCorner(
                      registry: scope.feelings,
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
/// How much of the bottom of the screen the tab strip takes, including the safe area under it.
/// A surface laid over the app has to clear it: the media viewer's `put it back` sat exactly on
/// top of `chat` and `moments`, two sets of words in the same place.
const double kTabStrip = 44 + 18;

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
                  child: SizedBox(
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Five cards cut from a sheet of index card, and each one has to be a
                        // different piece of it. Covering the card with the whole 1288x1800 sheet
                        // scaled a sheet down to forty-four points and averaged its tooth away:
                        // five stamps of one swatch, correlating at 0.99 with each other. So the
                        // card shows a window onto the sheet at the sheet's own pixel density,
                        // and each tab looks through a different window.
                        Positioned.fill(child: ColoredBox(color: Paper.index)),
                        if (card.isNotEmpty)
                          Positioned.fill(
                            child: Opacity(
                              opacity: i == index ? 1.0 : 0.82,
                              child: ClipRect(
                                child: Image.asset(
                                  paperAsset(card[i % card.length]),
                                  fit: BoxFit.none,
                                  alignment: _cardWindows[i % _cardWindows.length],
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder: PaperPiece.none,
                                ),
                              ),
                            ),
                          ),
                        // and the label shrinks to fit its card rather than wrapping: five
                        // stamps across a 360-point screen leaves SETTINGS about a point short
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Stamped(labels[i],
                              size: i == index ? 12 : 11,
                              spacing: labels[i].length > 6 ? 1.0 : 1.6,
                              colour: i == index ? Pen.stamp : Pen.margin),
                        ),
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

/// Where on the sheet each tab card was cut from. Spread over both axes so no two windows share a
/// band of the ruling, and off the sheet's centre, where every stock is at its most uniform.
const List<Alignment> _cardWindows = [
  Alignment(-0.82, -0.64),
  Alignment(0.41, -0.88),
  Alignment(-0.35, 0.77),
  Alignment(0.88, 0.22),
  Alignment(-0.93, 0.09),
];
