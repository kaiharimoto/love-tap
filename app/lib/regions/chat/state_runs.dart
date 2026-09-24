// A run of phone states between two things said is one line in the margin, not a stack of them.
//
// 02_chat, the hero, showed eight full-width strips of "noor's phone is on normal", "noor went
// out", "you got in" and not one written message: a phone reports about its owner all day, and
// every report that survived the projection's once-an-hour filter took a whole row of the
// conversation. Three critics at cycle 3 read that as the thread being about the phones.
//
// So the fold is a VIEW. The projection keeps every row -- search, the read marker, a scene's
// anchor and the report all index it -- and a run of consecutive state rows is drawn once, on its
// newest row, as one sentence that names what changed. The rows before it in the run are drawn as
// nothing. Nothing is removed from the spine or from `ThreadState.items`.
import '../../spine/event.dart';
import '../../spine/projections/thread.dart';
import '../../voice/subject.dart';
import 'renderers.dart';

/// Whether [item] is something a phone or a person declared about themselves, rather than
/// something said.
bool isStateRow(ThreadItem item) => item.type == 'state_declared' || item.type == 'state_passive';

/// The runs of consecutive state rows in a thread, by index.
class StateRuns {
  StateRuns(List<ThreadItem> items) {
    var start = -1;
    for (var i = 0; i <= items.length; i++) {
      final state = i < items.length && isStateRow(items[i]) && !items[i].deleted;
      if (state && start < 0) start = i;
      if (!state && start >= 0) {
        final run = items.sublist(start, i);
        _closing[i - 1] = run;
        for (var j = start; j < i - 1; j++) {
          folded.add(j);
        }
        start = -1;
      }
    }
  }

  final Map<int, List<ThreadItem>> _closing = {};

  /// The indices drawn as nothing: every state row in a run but the newest.
  final Set<int> folded = {};

  /// The run the row at [i] closes and speaks for, or null if it is not the newest row of one.
  List<ThreadItem>? closing(int i) => _closing[i];
}

/// One sentence for a run of state rows: the latest of each thing that changed, per person, in
/// the order it last changed, in the same words [summaryOf] gives a single row. A signal that
/// changed three times in the run is said once, at its newest value, because that is what is true
/// now; the rows that said the rest are still in the spine.
String runSentence(List<ThreadItem> run, {Person? me}) {
  final latest = <String, ThreadItem>{};
  for (final it in run) {
    final key = '${it.author.name}/${it.event.payload['signal']}';
    latest.remove(key);
    latest[key] = it;
  }
  final parts = <String>[];
  Person? last;
  for (final it in latest.values) {
    final s = summaryOf(it.event, me: me);
    // "noor went out · noor's phone is on normal" says her name twice in one breath; after the
    // first, the same person's changes carry on without it
    final who = me != null && it.author == me ? const Subject.you() : Subject.named(it.author.name);
    final bare = it.author == last ? _withoutWho(s, who) : s;
    parts.add(bare);
    last = it.author;
  }
  return parts.join(' · ');
}

String _withoutWho(String s, Subject who) {
  final name = '$who';
  final possessive = who.possessive;
  if (s.startsWith('$possessive ')) return s.substring(possessive.length + 1);
  // where someone is, which summaryOf says as `noor · the canal`
  if (s.startsWith('$name · ')) return s.substring(name.length + 3);
  if (s.startsWith('$name ')) return s.substring(name.length + 1);
  return s;
}
