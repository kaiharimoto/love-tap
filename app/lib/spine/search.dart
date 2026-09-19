// Full-text search over the spine: one inverted index over every searchable event type, plus
// facets, so search reaches every type rather than only text. In memory, rebuilt from the log.
import 'event.dart';
import 'types.dart';

class SearchHit {
  const SearchHit(this.event, this.score, {this.matchedIn = const [], this.matchedKind});
  final Event event;
  final double score;

  /// The strings this event was indexed under that carry one of the query's terms, in the order
  /// the type declares its text fields. A row draws the summary of the event, and a summary shows
  /// some of the fields and not others: `ritual_kept` prints `title · kept` and never its note, so
  /// a search for `rain` returned `text when home · kept` with nothing on it to see. The row shows
  /// one of these when the summary carries no match, so a hit is never a thing you have to take
  /// on trust.
  final List<String> matchedIn;

  /// Set when the only thing that matched was the kind of thing it is -- `photo`, `feelings`,
  /// `rituals`. Those are searchable on purpose, and a row that matched on one has nothing in its
  /// words to highlight.
  final String? matchedKind;
}

class SearchIndex {
  final Map<String, Map<String, int>> _postings = {}; // term -> id -> count
  final Map<String, Event> _byId = {};
  final Map<String, String> _editedText = {}; // target id -> latest edited text
  final Set<String> _deleted = {};

  static final RegExp _token = RegExp(r"[\p{L}\p{N}]+(?:['’][\p{L}]+)?", unicode: true);

  static List<String> tokenize(String text) =>
      _token.allMatches(text.toLowerCase()).map((m) => m.group(0)!).where((t) => t.isNotEmpty).toList();

  void clear() {
    _postings.clear();
    _byId.clear();
    _editedText.clear();
    _deleted.clear();
  }

  void add(Event e) {
    final spec = kEventTypeById[e.type];
    if (spec == null) return;
    if (e.type == 'message_delete') {
      final t = e.payload['target'] as String?;
      if (t != null) {
        _deleted.add(t);
        _remove(t);
      }
      return;
    }
    if (e.type == 'message_edit') {
      final t = e.payload['target'] as String?;
      final text = e.payload['text'] as String?;
      if (t != null && text != null && _byId.containsKey(t) && !_deleted.contains(t)) {
        _remove(t);
        _editedText[t] = text;
        _index(_byId[t]!, override: text);
      }
      return;
    }
    if (spec.search.excluded) return;
    if (_deleted.contains(e.id)) return;
    _index(e);
  }

  /// The strings an event is indexed under: the words of it, then the words for the kind of thing
  /// it is. Both halves are asked of the registry rather than listed here, and the query side
  /// asks the same function, so what a row can say it matched on cannot drift from what was
  /// actually indexed.
  ///
  /// `override` is the current text of an edited message, which replaces the stored text.
  (List<String>, List<String>) _sourcesOf(Event e, {String? override}) {
    final spec = kEventTypeById[e.type]!;
    final words = <String>[];
    if (override != null) {
      words.add(override);
    } else {
      for (final f in spec.search.textFields) {
        final v = e.payload[f];
        if (v is String && v.isNotEmpty) words.add(v);
      }
    }
    if (e.type == 'feeling' || e.type == 'reaction') {
      final f = e.payload['feeling_id'] as String?;
      if (f != null) words.add(f);
    }
    if (e.type == 'state_declared') {
      final sig = e.payload['signal'] as String?;
      if (sig != null) words.add(sig);
    }
    // type and facet terms so "photo" or "feeling" finds by kind
    final kinds = <String>[e.type, ...spec.search.facets];
    return (words, kinds);
  }

  void _index(Event e, {String? override}) {
    _byId[e.id] = e;
    final counts = <String, int>{};
    void addText(String? s) {
      if (s == null) return;
      for (final t in tokenize(s)) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final (words, kinds) = _sourcesOf(e, override: override);
    words.forEach(addText);
    kinds.forEach(addText);
    for (final entry in counts.entries) {
      (_postings[entry.key] ??= {})[e.id] = entry.value;
    }
  }

  void _remove(String id) {
    for (final p in _postings.values) {
      p.remove(id);
    }
  }

  /// Text of an indexed message after edits (for rendering search results).
  String? currentText(String id) => _editedText[id];

  List<SearchHit> search(String query, {Set<String>? types, Person? author, int? fromTs, int? toTs, int limit = 200}) {
    final terms = tokenize(query);
    if (terms.isEmpty) return const [];
    final scores = <String, double>{};
    for (final term in terms) {
      final exact = _postings[term];
      final matches = <String, int>{};
      if (exact != null) matches.addAll(exact);
      // prefix match for the last term while typing
      if (term == terms.last) {
        for (final entry in _postings.entries) {
          if (entry.key.startsWith(term) && entry.key != term) {
            for (final e in entry.value.entries) {
              matches[e.key] = (matches[e.key] ?? 0) + e.value;
            }
          }
        }
      }
      if (matches.isEmpty) return const [];
      final idf = 1.0 + (1.0 / (1 + matches.length));
      final next = <String, double>{};
      for (final m in matches.entries) {
        if (term != terms.first && !scores.containsKey(m.key)) continue;
        next[m.key] = (scores[m.key] ?? 0) + m.value * idf;
      }
      scores
        ..clear()
        ..addAll(next);
    }
    final hits = <SearchHit>[];
    for (final s in scores.entries) {
      final e = _byId[s.key];
      if (e == null) continue;
      if (types != null && !types.contains(e.type)) continue;
      if (author != null && e.author != author) continue;
      if (fromTs != null && e.ts < fromTs) continue;
      if (toTs != null && e.ts > toTs) continue;
      final (words, kinds) = _sourcesOf(e, override: _editedText[e.id]);
      final carried = [for (final w in words) if (carries(w, terms)) w];
      hits.add(SearchHit(e, s.value,
          matchedIn: carried,
          matchedKind: carried.isNotEmpty ? null : _firstCarrying(kinds, terms)));
    }
    // Newest first, and nothing else. It sorted by score with the timestamp only as a tiebreak,
    // which is why one day's hits came out 07:20, 07:24, 07:14: three results a person reads as a
    // sequence, in an order derived from a number that is nowhere on the screen. A relevance rank
    // needs a reason to be believed, and a year of one conversation does not give it one -- the
    // question somebody is asking a search box here is `when did we say that`, and the answer to
    // that is a date. The score still chooses which hits there are; it no longer chooses what
    // order they are read in. The id breaks a tie so two events written in the same millisecond
    // do not swap places between two runs of the same query.
    hits.sort((a, b) {
      final c = b.event.ts.compareTo(a.event.ts);
      return c != 0 ? c : b.event.id.compareTo(a.event.id);
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  static String? _firstCarrying(List<String> texts, List<String> terms) {
    for (final t in texts) {
      if (carries(t, terms)) return t;
    }
    return null;
  }

  /// Whether one of [terms] is a word of [text] or the start of one -- the same match the index
  /// makes, so a highlighted word is a word the index actually matched on.
  static bool carries(String text, List<String> terms) => spansIn(text, terms).isNotEmpty;

  /// Where in [text] the words of [query] are, as (start, end) ranges over the original string,
  /// in order and never overlapping. The highlighter draws these.
  ///
  /// A whole word at a time, because that is what the index matched: it holds tokens, it matches
  /// the last term of a query as a prefix while somebody is still typing, and it knows nothing
  /// about a query as one literal run of characters. The highlighter did know it as one, so a
  /// two-word query lit nothing unless the two words happened to be adjacent in the line.
  static List<(int, int)> spansOf(String text, String query) =>
      spansIn(text, tokenize(query));

  static List<(int, int)> spansIn(String text, List<String> terms) {
    if (terms.isEmpty) return const [];
    final out = <(int, int)>[];
    for (final m in _token.allMatches(text)) {
      final word = m.group(0)!.toLowerCase();
      for (final q in terms) {
        if (word == q || word.startsWith(q)) {
          out.add((m.start, m.end));
          break;
        }
      }
    }
    return out;
  }
}
