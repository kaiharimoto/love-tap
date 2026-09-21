// Who a sentence is about, and the grammar that follows from being them.
//
// `docs/VOICE.md` rule 3 says the two people are Noor and Teo, or "you" spoken as a person would.
// "you" was not being spoken as a person would. `summaryOf` set `who` to the literal string 'you'
// when the event was the reader's own and dropped it into templates written for a third-person
// subject, so a person looking at their own phone was told:
//
//     you's phone is nearly out          you's phone is on silent
//     you's signal is wifi               you was up an hour ago
//     it is nine where you is            you needs a little
//     you has a lot left                 you is charging
//     you is tender                      you has read up to here
//
// Ten sentences, of which the item that caught this named five; the other five are the same
// mistake in `need`, `energy`, `charging`, the three `is` signals and the read marker.
//
// **The string lint cannot see any of it and that is the interesting half.**
// `tools/lint/strings.py` walks Dart literals that reach a display call. Every fragment above is
// a correct literal: `"$who's phone is on $words"` is a good sentence for every value `who` can
// take except one. The defect only exists once the template and the name are composed, at
// runtime, which is a place no lint over the string table can reach — `docs/VOICE.md` is enforced
// over the string table and the string table is not every displayed string.
//
// So the fix is not a better literal. It is to stop `who` being a string at all: a subject knows
// which person it is, and the sentence asks it for the verb rather than assuming one.
class Subject {
  const Subject(this.name, {required this.isYou});

  /// The reader themselves.
  const Subject.you() : name = 'you', isYou = true;

  /// The other person, by name.
  const Subject.named(this.name) : isYou = false;

  /// What goes in the sentence where the subject goes. Lower case, like every other name in this
  /// app — `docs/VOICE.md` rule 5.
  final String name;

  /// Whether this is the person holding the phone, which is the only thing the grammar turns on.
  final bool isYou;

  /// `your phone`, `noor's phone`. Never `you's`, which is where this came in.
  String get possessive => isYou ? 'your' : "$name's";

  /// The present tense of *to be*: `you are`, `noor is`.
  String get be => isYou ? 'are' : 'is';

  /// The past tense of *to be*: `you were`, `noor was`.
  String get were => isYou ? 'were' : 'was';

  /// The present tense of *to have*: `you have`, `noor has`.
  String get have => isYou ? 'have' : 'has';

  /// A present-tense verb agreeing with this subject. The third person takes the -s and the
  /// second person does not: `you need`, `noor needs`.
  ///
  /// Given the bare stem, so a sentence reads `${who.does('need')}` and cannot be written half
  /// one way and half the other.
  String does(String stem) => isYou ? stem : '$stem${stem.endsWith('s') ? 'es' : 's'}';

  /// So `'$who sent a photograph'` keeps working: the sentences where the subject takes no verb
  /// of its own were never wrong and are not rewritten.
  @override
  String toString() => name;
}
