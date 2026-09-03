// Full-text search over the spine: one inverted index over every searchable event type, plus
// facets, so search reaches every type rather than only text. In memory, rebuilt from the log.
import 'event.dart';
import 'types.dart';

class SearchHit {
  const SearchHit(this.event, this.score);
  final Event event;
  final double score;
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

  void _index(Event e, {String? override}) {
    _byId[e.id] = e;
    final spec = kEventTypeById[e.type]!;
    final counts = <String, int>{};
    void addText(String? s) {
      if (s == null) return;
      for (final t in tokenize(s)) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    if (override != null) {
      addText(override);
    } else {
      for (final f in spec.search.textFields) {
        final v = e.payload[f];
        if (v is String) addText(v);
      }
    }
    // type and facet terms so "photo" or "feeling" finds by kind
    addText(e.type);
    for (final f in spec.search.facets) {
      addText(f);
    }
    if (e.type == 'feeling' || e.type == 'reaction') addText(e.payload['feeling_id'] as String?);
    if (e.type == 'state_declared') addText(e.payload['signal'] as String?);
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
      hits.add(SearchHit(e, s.value));
    }
    hits.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : b.event.ts.compareTo(a.event.ts);
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }
}
