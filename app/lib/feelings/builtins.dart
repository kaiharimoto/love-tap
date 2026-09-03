// The shipped vocabulary. docs/FEELINGS.md is the contract; the test compares the two.
// Authored feelings join this list at runtime (feelings/registry.dart) and are indistinguishable.

enum Family { warmth, ache, shelter, mischief, static_, sparkle }

extension FamilyName on Family {
  String get label => switch (this) {
        Family.warmth => 'Warmth',
        Family.ache => 'Ache',
        Family.shelter => 'Shelter',
        Family.mischief => 'Mischief',
        Family.static_ => 'Static',
        Family.sparkle => 'Sparkle',
      };

  static Family parse(String s) => Family.values.firstWhere((f) => f.label.toLowerCase() == s.toLowerCase());
}

/// One haptic segment: on for [ms] at [amp] (0–255), or off for [ms] when [amp] == 0.
class HapticSegment {
  const HapticSegment(this.ms, this.amp);
  final int ms;
  final int amp;
  bool get on => amp > 0;
}

/// Parses `80@90 off40 160@160` and `(25@255 off25) ×5` into segments.
List<HapticSegment> parseHaptic(String s) {
  final out = <HapticSegment>[];
  var text = s.trim();
  // expand "(...) ×N" and "X ×N"
  final group = RegExp(r'\(([^)]+)\)\s*×(\d+)');
  text = text.replaceAllMapped(group, (m) => List.filled(int.parse(m.group(2)!), m.group(1)!).join(' '));
  final trailing = RegExp(r'^(.*?)\s*×(\d+)$');
  final tm = trailing.firstMatch(text);
  if (tm != null) text = List.filled(int.parse(tm.group(2)!), tm.group(1)!).join(' ');
  for (final tok in text.split(RegExp(r'\s+'))) {
    if (tok.isEmpty) continue;
    if (tok.startsWith('off')) {
      out.add(HapticSegment(int.parse(tok.substring(3)), 0));
    } else {
      final parts = tok.split('@');
      out.add(HapticSegment(int.parse(parts[0]), int.parse(parts[1])));
    }
  }
  return out;
}

class Feeling {
  const Feeling({
    required this.id,
    required this.name,
    required this.family,
    required this.object,
    required this.haptic,
    required this.sound,
    required this.colour,
    this.authoredBy,
    this.retired = false,
  });

  final String id;

  /// Shown in the author's hand.
  final String name;
  final Family family;

  /// Object asset id (`assets/objects/<object>.png`).
  final String object;

  /// The haptic sequence in docs/FEELINGS.md notation.
  final String haptic;

  /// Sound id (`assets/sound/<sound>.ogg`).
  final String sound;

  /// Ink or stationery colour, #rrggbb.
  final String colour;

  /// Null for built-ins; the person who made it otherwise.
  final String? authoredBy;
  final bool retired;

  List<HapticSegment> get segments => parseHaptic(haptic);
  int get hapticLengthMs => segments.fold(0, (n, s) => n + s.ms);
  bool get builtIn => authoredBy == null;
}

const List<Feeling> kBuiltInFeelings = [
  Feeling(id: 'squeeze', name: 'a squeeze', family: Family.warmth, object: 'obj_heart_fold', haptic: '80@90 off40 160@160 off40 320@230', sound: 'snd_squeeze', colour: '#1f2a44'),
  Feeling(id: 'forehead', name: 'forehead', family: Family.warmth, object: 'obj_thumbprint', haptic: '200@120 off120 200@120', sound: 'snd_forehead', colour: '#1f2a44'),
  Feeling(id: 'warm_palm', name: 'warm palm', family: Family.warmth, object: 'obj_coffee_ring', haptic: '600@140', sound: 'snd_palm', colour: '#a67c52'),
  Feeling(id: 'nuzzle', name: 'nuzzle', family: Family.warmth, object: 'obj_clover', haptic: '90@150 off60 90@150 off60 90@150 off200 400@110', sound: 'snd_nuzzle', colour: '#5d7a4a'),
  Feeling(id: 'thinking_of_you', name: 'thinking of you', family: Family.warmth, object: 'obj_margin_sun', haptic: '40@80 off300 40@80 off300 260@170', sound: 'snd_thinking', colour: '#1f2a44'),
  Feeling(id: 'goodnight', name: 'goodnight', family: Family.warmth, object: 'obj_corner_moon', haptic: '500@120 off200 250@80 off200 120@50', sound: 'snd_goodnight', colour: '#2c3555'),
  Feeling(id: 'miss_you', name: 'miss you', family: Family.ache, object: 'obj_crane', haptic: '150@220 off600 150@150 off600 150@90', sound: 'snd_miss', colour: '#3a3a3c'),
  Feeling(id: 'empty_chair', name: 'empty chair', family: Family.ache, object: 'obj_chair', haptic: '300@200 off900 300@100', sound: 'snd_chair', colour: '#3a3a3c'),
  Feeling(id: 'come_home', name: 'come home', family: Family.ache, object: 'obj_string_loop', haptic: '60@255 off200 60@255 off200 60@255 off800 400@120', sound: 'snd_home', colour: '#6b5a3e'),
  Feeling(id: 'wish_you_were_here', name: 'wish you were here', family: Family.ache, object: 'obj_ticket', haptic: '250@180 off400 250@120 off400 250@70 off400 250@40', sound: 'snd_wish', colour: '#8a6a4a'),
  Feeling(id: 'long_day', name: 'long day', family: Family.ache, object: 'obj_window', haptic: '800@100 off300 800@60', sound: 'snd_longday', colour: '#3a3a3c'),
  Feeling(id: 'here', name: 'here', family: Family.shelter, object: 'obj_boat', haptic: '400@140 off400 400@140 off400 400@140', sound: 'snd_here', colour: '#4a4a4c'),
  Feeling(id: 'breathe', name: 'breathe', family: Family.shelter, object: 'obj_blanket_fold', haptic: '1200@110 off800 1200@110', sound: 'snd_breathe', colour: '#4a4a4c'),
  Feeling(id: 'its_okay', name: "it's okay", family: Family.shelter, object: 'obj_plaster', haptic: '200@160 off200 200@160 off200 200@160 off200 200@160', sound: 'snd_okay', colour: '#c9a98a'),
  Feeling(id: 'steady', name: 'steady', family: Family.shelter, object: 'obj_stone', haptic: '300@180 off300 300@180 off300 300@180 off300 300@180 off300 300@180', sound: 'snd_steady', colour: '#6d6d70'),
  Feeling(id: 'make_you_tea', name: "i'll make you tea", family: Family.shelter, object: 'obj_mug', haptic: '100@120 off100 100@120 off100 500@150', sound: 'snd_tea', colour: '#8b6b4a'),
  Feeling(id: 'hold', name: 'hold', family: Family.shelter, object: 'obj_candle', haptic: '900@150 off100 900@150', sound: 'snd_hold', colour: '#b89a5a'),
  Feeling(id: 'poke', name: 'poke', family: Family.mischief, object: 'obj_spitball', haptic: '30@255', sound: 'snd_poke', colour: '#a8322b'),
  Feeling(id: 'nyeh', name: 'nyeh', family: Family.mischief, object: 'obj_tongue_face', haptic: '30@200 off50 30@200 off50 90@255', sound: 'snd_nyeh', colour: '#a8322b'),
  Feeling(id: 'catch', name: 'catch', family: Family.mischief, object: 'obj_plane', haptic: '40@120 off30 40@160 off30 40@200 off30 40@240 off30 120@255', sound: 'snd_catch', colour: '#a8322b'),
  Feeling(id: 'pick_one', name: 'pick one', family: Family.mischief, object: 'obj_fortune_teller', haptic: '50@180 off120 ×6', sound: 'snd_pick', colour: '#e0a8b8'),
  Feeling(id: 'snap', name: 'snap', family: Family.mischief, object: 'obj_rubber_band', haptic: '20@255 off40 60@255 off400 20@180', sound: 'snd_snap', colour: '#c98a5a'),
  Feeling(id: 'stuck_with_me', name: 'stuck with me', family: Family.mischief, object: 'obj_staple_chain', haptic: '30@220 off30 ×8', sound: 'snd_stuck', colour: '#7a7a7e'),
  Feeling(id: 'overwhelmed', name: 'overwhelmed', family: Family.static_, object: 'obj_crumple_ball', haptic: '(25@255 off25 25@200 off25) ×5', sound: 'snd_overwhelmed', colour: '#141a2e'),
  Feeling(id: 'ugh', name: 'ugh', family: Family.static_, object: 'obj_scribble', haptic: '180@255 off60 180@255 off60 180@255', sound: 'snd_ugh', colour: '#141a2e'),
  Feeling(id: 'snapped', name: 'snapped', family: Family.static_, object: 'obj_snapped_pencil', haptic: '15@255 off15 15@255 off15 15@255 off300 500@255', sound: 'snd_snapped', colour: '#3a3a3c'),
  Feeling(id: 'tangled', name: 'tangled', family: Family.static_, object: 'obj_knot', haptic: '40@180 off20 80@220 off20 40@180 off20 120@255 off20 40@180 off20 80@220', sound: 'snd_tangled', colour: '#6b5a3e'),
  Feeling(id: 'grey', name: 'grey', family: Family.static_, object: 'obj_rain', haptic: '(60@70 off60) ×8', sound: 'snd_grey', colour: '#8a8a8e'),
  Feeling(id: 'not_okay', name: 'not okay', family: Family.static_, object: 'obj_torn_corner', haptic: '400@255 off100 40@255 off100 40@255 off100 40@255', sound: 'snd_notokay', colour: '#141a2e'),
  Feeling(id: 'did_it', name: 'did it', family: Family.sparkle, object: 'obj_gold_star', haptic: '40@120 off60 40@170 off60 40@220 off60 200@255', sound: 'snd_didit', colour: '#c9a23a'),
  Feeling(id: 'confetti', name: 'confetti', family: Family.sparkle, object: 'obj_confetti', haptic: '30@150 off40 30@190 off40 30@230 off40 30@255 off40 30@230 off40 30@190 off40 30@150', sound: 'snd_confetti', colour: '#f2a8c0'),
  Feeling(id: 'yes', name: 'yes', family: Family.sparkle, object: 'obj_firework', haptic: '60@100 off40 60@180 off40 60@255 off200 60@255 off40 60@255', sound: 'snd_yes', colour: '#a8322b'),
  Feeling(id: 'crown', name: 'crown', family: Family.sparkle, object: 'obj_crown', haptic: '100@120 off100 100@170 off100 100@220 off100 100@255 off300 300@255', sound: 'snd_crown', colour: '#f4ea6a'),
  Feeling(id: 'treat', name: 'treat', family: Family.sparkle, object: 'obj_ribbon', haptic: '50@200 off80 50@200 off80 300@150 off80 50@255', sound: 'snd_treat', colour: '#f2a8c0'),
];

final Map<String, Feeling> kBuiltInById = {for (final f in kBuiltInFeelings) f.id: f};
