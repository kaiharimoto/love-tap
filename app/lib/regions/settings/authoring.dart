// Making a feeling. Whatever comes out of here behaves exactly like a built-in one: it is a
// feeling_authored event in the same spine, and every path — the sender, the thread, the
// notification, Moments, search — reads it from the same registry without asking where it came
// from. A name in your hand, a family (which gives it its haptic shape and its paper), an object
// from the drawer, and a rhythm you tap out yourself.
import 'package:flutter/material.dart';

import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../material/hands.dart';
import '../../material/library.dart';
import '../../material/objects.dart';
import '../../material/palette.dart';
import '../../spine/spine.dart';

class AuthoringSheet extends StatefulWidget {
  const AuthoringSheet({super.key, required this.registry, required this.me});

  final FeelingRegistry registry;
  final Person me;

  /// Returns the feeling_authored payload, or null.
  static Future<Map<String, dynamic>?> open(BuildContext context, {required FeelingRegistry registry, required Person me}) =>
      showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFF1ECDF),
        builder: (ctx) => AuthoringSheet(registry: registry, me: me),
      );

  @override
  State<AuthoringSheet> createState() => _AuthoringSheetState();
}

class _AuthoringSheetState extends State<AuthoringSheet> {
  final _name = TextEditingController();
  Family _family = Family.warmth;
  String? _object;
  final List<int> _taps = [];
  DateTime? _lastTap;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The rhythm, tapped out: each tap is an `on` as long as the finger was down, each gap an `off`.
  String get _haptic {
    if (_taps.length < 2) {
      // the family's own shape, so a feeling made in a hurry still feels like its family
      return switch (_family) {
        Family.warmth => '80@90 off40 160@160 off40 320@230',
        Family.ache => '150@200 off600 150@140 off600 150@90',
        Family.shelter => '400@140 off400 400@140 off400 400@140',
        Family.mischief => '30@220 off60 30@220 off60 90@255',
        Family.static_ => '(25@240 off25) ×6',
        Family.sparkle => '40@120 off60 40@180 off60 200@255',
      };
    }
    final parts = <String>[];
    for (var i = 0; i < _taps.length; i++) {
      final ms = _taps[i].clamp(20, 1200);
      parts.add(i.isEven ? '$ms@${(120 + (i * 25)).clamp(60, 255)}' : 'off$ms');
    }
    return parts.join(' ');
  }

  List<String> get _drawer {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final ids = lib?.objectIds ?? const <String>[];
    return ids.isEmpty ? kBuiltInFeelings.map((f) => f.object).toList() : ids;
  }

  @override
  Widget build(BuildContext context) {
    final preview = Feeling(
      id: 'preview',
      name: _name.text.isEmpty ? 'no name yet' : _name.text,
      family: _family,
      object: _object ?? (_drawer.isEmpty ? 'obj_heart_fold' : _drawer.first),
      haptic: _haptic,
      sound: 'snd_${_family.label.toLowerCase()}_made',
      colour: switch (_family) {
        Family.warmth => '#1f2a44',
        Family.ache => '#3a3a3c',
        Family.shelter => '#4a4a4c',
        Family.mischief => '#a8322b',
        Family.static_ => '#141a2e',
        Family.sparkle => '#c9a23a',
      },
      authoredBy: widget.me.name,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Stamped('a feeling of your own', size: 11),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                style: Hands.of(widget.me, size: 21),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'what it is called',
                  hintStyle: Hands.margin(size: 17),
                  border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 14),
              Stamped('which register', size: 9, colour: Pen.margin),
              Wrap(
                spacing: 12,
                children: [
                  for (final f in Family.values)
                    GestureDetector(
                      onTap: () => setState(() => _family = f),
                      child: Text(
                        f.label.toLowerCase(),
                        style: Hands.margin(size: 16).copyWith(
                          color: f == _family ? Pen.stamp : Pen.margin.withValues(alpha: 0.6),
                          decoration: f == _family ? TextDecoration.underline : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Stamped('what it looks like', size: 9, colour: Pen.margin),
              SizedBox(
                height: 84,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final o in _drawer.take(30))
                      GestureDetector(
                        onTap: () => setState(() => _object = o),
                        child: Opacity(
                          opacity: (_object ?? _drawer.first) == o ? 1 : 0.5,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Image.asset(objectAsset(o), width: 64, errorBuilder: (c, e, s) => const SizedBox(width: 64)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Stamped('how it should feel', size: 9, colour: Pen.margin),
              const SizedBox(height: 4),
              GestureDetector(
                onTapDown: (_) => _lastTap = DateTime.now(),
                onTapUp: (_) {
                  final down = _lastTap;
                  if (down == null) return;
                  final ms = DateTime.now().difference(down).inMilliseconds;
                  setState(() {
                    if (_taps.isNotEmpty) _taps.add(160);
                    _taps.add(ms);
                  });
                },
                child: Container(
                  height: 64,
                  alignment: Alignment.center,
                  color: const Color(0xFFF3EEE3),
                  child: Text(
                    _taps.isEmpty ? 'tap out the rhythm here' : _haptic,
                    style: Hands.margin(size: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FeelingObject(feeling: preview, size: 72, intensity: 0.8),
                  const SizedBox(width: 12),
                  Expanded(child: Text(preview.name, style: Hands.of(widget.me, size: 19))),
                  GestureDetector(
                    onTap: _name.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, {
                              'feeling_id': 'made_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
                              'name': _name.text.trim(),
                              'family': _family.label,
                              'colour': preview.colour,
                              'object_asset': preview.object,
                              'haptic': _haptic,
                              'sound': preview.sound,
                              'retired': false,
                            }),
                    child: Text('keep it',
                        style: Hands.margin(size: 16).copyWith(
                          color: _name.text.trim().isEmpty ? Pen.margin.withValues(alpha: 0.4) : Pen.stamp,
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
