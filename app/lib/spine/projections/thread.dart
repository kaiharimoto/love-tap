// The thread projection: what Chat renders. Every row is one spine event; edits, deletes,
// reactions and read markers fold into the row they point at and never appear as rows of
// their own. Rebuilt from the log alone; the golden test replays it.
import '../event.dart';
import '../types.dart';

/// What has happened to something you wrote, on its way to the other phone.
///
/// There were three of these, and two of them looked the same on screen — which meant a message
/// that had not gone anywhere was indistinguishable from one that had. These are the five states
/// a thing can actually be in, and note.dart gives each of them its own mark.
enum Delivery {
  /// Written while the other phone was out of reach. It is in the outbox and it will go.
  queued,

  /// The link is up and this is on its way.
  sending,

  /// Accepted by the host (it has a seq) but the partner has not read past it.
  sent,

  /// The partner's read marker covers it.
  read,

  /// The host would not take it. It is still here, and it is not going anywhere on its own.
  refused,
}

class Reaction {
  const Reaction({required this.by, required this.feelingId, required this.eventId, required this.at});
  final Person by;
  final String feelingId;
  final String eventId;
  final int at;
}

/// One row of the thread.
class ThreadItem {
  ThreadItem({
    required this.event,
    required this.text,
    required this.edited,
    required this.deleted,
    required this.reactions,
    required this.replyTo,
    required this.delivery,
    required this.writtenEarlier,
  });

  final Event event;

  /// Current text after edits (messages), caption (media), or null.
  final String? text;
  final bool edited;

  /// "took this back": the row stays as a stub.
  final bool deleted;
  final List<Reaction> reactions;

  /// The event this one answers, if any (resolved, may be null if unknown).
  final Event? replyTo;
  final Delivery delivery;

  /// Authored well before it arrived (sent from the outbox after a gap).
  final bool writtenEarlier;

  String get id => event.id;
  String get type => event.type;
  Person get author => event.author;
  int get ts => event.ts;
}

class ThreadState {
  ThreadState({required this.items, required this.readUpto, required this.byId});

  /// Rows in thread order (host order, pending last).
  final List<ThreadItem> items;

  /// Highest seq each person has read.
  final Map<Person, int> readUpto;
  final Map<String, ThreadItem> byId;

  /// Unread for [me]: rows by the other person with seq above my marker.
  int unreadFor(Person me) {
    final upto = readUpto[me] ?? 0;
    return items.where((i) => i.author != me && (i.event.seq ?? 1 << 40) > upto).length;
  }

  /// The seq my read marker should advance to when I look at the thread.
  int? latestSeq() {
    for (var i = items.length - 1; i >= 0; i--) {
      final s = items[i].event.seq;
      if (s != null) return s;
    }
    return null;
  }
}

/// Which passive signals are worth a mark in the margin, and how often.
///
/// Three things a phone knows are worth saying out loud: that it is nearly out of battery, that
/// its owner has come in or gone out, and that it has been put on silent. Everything else — the
/// network it is on, whether it is moving, the hour where they are — belongs to the partner strip,
/// where it is a fact about them rather than a line in the conversation.
const Map<String, Set<String>> _saidPassive = {
  'battery': {'low'},
  'at_home': {'true', 'false'},
  'ringer': {'silent', 'normal'},
};

String _passiveKey(Event e) => '${e.author.name}.${e.payload['signal']}';

/// The mark this signal would leave, or null if it leaves none. At most one an hour per signal
/// per person, so a phone that flickers between two networks says nothing at all.
String? _worthSaying(Event e, Map<String, int> last) {
  final signal = e.payload['signal'] as String?;
  final allowed = _saidPassive[signal];
  if (allowed == null) return null;
  final value = e.payload['value'];
  final word = signal == 'battery'
      ? ((value is num && value <= 12) ? 'low' : null)
      : '$value';
  if (word == null || !allowed.contains(word)) return null;
  final since = last[_passiveKey(e)];
  if (since != null && e.ts - since < 3600 * 1000) return null;
  return word;
}

/// Builds the thread from the log, from nothing.
///
/// The log is put in order first rather than trusted to arrive in it. An edit that reaches this
/// device before the message it edits, or a reaction that arrives before its target, is exactly
/// what a phone that has been offline for a day produces when it catches up, and a projection that
/// reads its input in arrival order silently drops both. Order is the host-assigned seq, then the
/// timestamp, then the id, so two devices holding the same events always draw the same thread
/// whatever order they received them in.
///
/// This does the whole year every time, which measured at 177 milliseconds over fourteen thousand
/// events — eleven frames. It is what the golden test and every other caller wants, and it is what
/// [ThreadProjector] falls back to; what the app scrolling against a year of history uses is the
/// projector, which folds in what is new.
ThreadState projectThread(List<Event> events, {Person? me, bool linkUp = true,
    Map<String, String> refused = const {}, Set<String> inFlight = const {}}) =>
    (ThreadProjector(me: me)..fold(inLogOrder(events)))
        .assemble(linkUp: linkUp, refused: refused, inFlight: inFlight);

/// The thread, kept rather than rebuilt.
///
/// One log and no second store means the thread is a function of the events — but it does not mean
/// recomputing that function from the first event of the year every time somebody scrolls. The
/// spine appends, so the ordinary case is that everything this has already folded in is still
/// there, unchanged, followed by something new; that case costs the new events and nothing else.
/// Anything else — an event arriving out of order, the log shrinking, a different log entirely —
/// is detected and rebuilt from scratch, so the answer is always the one the free function above
/// would have given. thread_incremental_test holds it to exactly that.
class ThreadProjector {
  ThreadProjector({this.me});

  final Person? me;

  final Map<String, _Row> _rows = {};
  final List<String> _order = [];
  final Map<Person, int> _readUpto = {};
  final Map<String, int> _lastPassive = {};

  /// Rows whose ThreadItem has to be built again: new ones, and ones an edit, a delete or a
  /// reaction has landed on since the last assembly.
  final Set<String> _dirty = {};
  final Map<String, ThreadItem> _items = {};

  /// How much of the log has been folded in, and what the last of it was — enough to tell an
  /// append from anything else without comparing the whole list.
  int _seen = 0;
  String _lastId = '';

  /// Rows this device wrote that have a seq, kept in seq order, so a read marker moving can mark
  /// exactly the rows whose delivery it changes instead of every row of the year.
  final List<int> _mineSeqs = [];
  final List<String> _mineIds = [];

  /// Rows still in the outbox. Whether the link is up, what is in flight and what was refused can
  /// only change the margin of these.
  final Set<String> _pending = {};

  /// The state of the delivery inputs at the last assembly.
  int _assembledRead = 0;
  int _assembledRefused = -1;
  int _assembledInFlight = -1;
  bool _assembledLinkUp = true;

  /// Fold in everything of [ordered] that has not been folded in yet, rebuilding if it is not an
  /// append to what is already here.
  void fold(List<Event> ordered) {
    if (ordered.length < _seen ||
        (_seen > 0 && (ordered.length < _seen || ordered[_seen - 1].id != _lastId))) {
      _reset();
    }
    for (var i = _seen; i < ordered.length; i++) {
      _apply(ordered[i]);
    }
    _seen = ordered.length;
    if (_seen > 0) _lastId = ordered[_seen - 1].id;
  }

  void _reset() {
    _rows.clear();
    _order.clear();
    _readUpto.clear();
    _lastPassive.clear();
    _items.clear();
    _dirty.clear();
    _mineSeqs.clear();
    _mineIds.clear();
    _pending.clear();
    _seen = 0;
    _lastId = '';
    _assembledRead = 0;
    _assembledRefused = -1;
    _assembledInFlight = -1;
  }

  void _apply(Event e) {
    final spec = kEventTypeById[e.type];
    if (spec == null) return;
    switch (e.type) {
      case 'message_edit':
        final t = e.payload['target'] as String?;
        final row = t == null ? null : _rows[t];
        if (row != null && row.event.author == e.author) {
          row.text = e.payload['text'] as String?;
          row.edited = true;
          _dirty.add(t!);
        }
        return;
      case 'message_delete':
        final t = e.payload['target'] as String?;
        final row = t == null ? null : _rows[t];
        if (row != null && row.event.author == e.author) {
          row.deleted = true;
          _dirty.add(t!);
        }
        return;
      case 'reaction':
        final t = e.payload['target'] as String?;
        final row = t == null ? null : _rows[t];
        if (row != null) {
          row.reactions.removeWhere(
              (r) => r.by == e.author && r.feelingId == e.payload['feeling_id']);
          row.reactions.add(Reaction(by: e.author, feelingId: e.payload['feeling_id'] as String,
              eventId: e.id, at: e.ts));
          _dirty.add(t!);
        }
        return;
      case 'state_passive':
        // A phone reports about its owner all day, and almost none of it belongs in a
        // conversation: docs/EVENT_TYPES.md says one margin mark per meaningful transition per
        // hour, and the rest folded into the partner strip only. A battery level is not a thing
        // either of them said.
        final mark = _worthSaying(e, _lastPassive);
        if (mark == null) return;
        _lastPassive[_passiveKey(e)] = e.ts;
        _add(e);
        return;
      case 'read_marker':
        final upto = e.payload['upto_seq'];
        if (upto is int) {
          final prev = _readUpto[e.author] ?? 0;
          if (upto > prev) _readUpto[e.author] = upto;
        }
        return;
    }
    if (!spec.rowInThread) return;
    _add(e);
  }

  void _add(Event e) {
    _rows[e.id] = _Row(e);
    _order.add(e.id);
    _dirty.add(e.id);
    if (e.author == me) {
      final seq = e.seq;
      if (seq == null) {
        _pending.add(e.id);
      } else {
        // the log is folded in seq order, so this stays sorted by construction
        _mineSeqs.add(seq);
        _mineIds.add(e.id);
      }
    }
  }

  /// The first index in [_mineSeqs] whose seq is greater than [seq].
  int _after(int seq) {
    var lo = 0, hi = _mineSeqs.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_mineSeqs[mid] <= seq) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// The thread as it stands. Only rows whose inputs have changed are built again.
  ThreadState assemble({bool linkUp = true, Map<String, String> refused = const {},
      Set<String> inFlight = const {}}) {
    // A read marker moving changes the margin of rows it has just covered, and of no others. The
    // first version of this re-marked every row this device wrote — half a year of them — which
    // cost more than the thing it was avoiding. The rows it covers are exactly mine with a seq in
    // (what it covered before, what it covers now], so they are found by binary search.
    final now = _readUpto[me?.other] ?? 0;
    if (now != _assembledRead) {
      final from = _after(_assembledRead < now ? _assembledRead : 0);
      final to = _after(now);
      for (var i = from; i < to && i < _mineIds.length; i++) {
        _dirty.add(_mineIds[i]);
      }
      // a marker that went backwards should not happen, but if it does, rebuild what it uncovered
      if (now < _assembledRead) {
        for (var i = _after(now); i < _after(_assembledRead) && i < _mineIds.length; i++) {
          _dirty.add(_mineIds[i]);
        }
      }
      _assembledRead = now;
    }

    // The link going down, or something being refused or picked up for sending, can only change
    // the margin of what is still in the outbox.
    if (refused.length != _assembledRefused ||
        inFlight.length != _assembledInFlight ||
        linkUp != _assembledLinkUp) {
      _dirty.addAll(_pending);
      _assembledRefused = refused.length;
      _assembledInFlight = inFlight.length;
      _assembledLinkUp = linkUp;
    }

    for (final id in _dirty) {
      final r = _rows[id];
      if (r == null) continue;
      final e = r.event;
      final theirRead = _readUpto[e.author.other] ?? 0;
      final delivery = e.seq != null
          ? (e.seq! <= theirRead ? Delivery.read : Delivery.sent)
          : refused.containsKey(e.id)
              ? Delivery.refused
              : (inFlight.contains(e.id) ? Delivery.sending
                  : linkUp ? Delivery.sending : Delivery.queued);
      Event? replyTo;
      final rt = e.payload['reply_to'];
      if (rt is String) replyTo = _rows[rt]?.event;
      _items[id] = ThreadItem(
        event: e,
        text: r.text ?? (e.payload['text'] as String?) ?? (e.payload['caption'] as String?),
        edited: r.edited,
        deleted: r.deleted,
        reactions: List.unmodifiable(r.reactions),
        replyTo: replyTo,
        delivery: delivery,
        writtenEarlier: e.seq == null ? false : (_arrivalHint(e) ?? false),
      );
    }
    _dirty.clear();

    final items = <ThreadItem>[];
    final byId = <String, ThreadItem>{};
    for (final id in _order) {
      final item = _items[id];
      if (item == null) continue;
      items.add(item);
      byId[id] = item;
    }
    return ThreadState(items: items, readUpto: Map.of(_readUpto), byId: byId);
  }

  /// Fold and assemble in one go: what the app calls on every spine change.
  ThreadState update(List<Event> log, {bool linkUp = true,
      Map<String, String> refused = const {}, Set<String> inFlight = const {}}) {
    fold(inLogOrder(log));
    return assemble(linkUp: linkUp, refused: refused, inFlight: inFlight);
  }
}

/// An event authored more than twenty minutes before the previous seq's author time was
/// written offline and delivered later. Cheap heuristic: compare with the payload flag when the
/// sender set it, else false. (The sync engine marks `written_earlier` on delivery gaps.)
bool? _arrivalHint(Event e) => e.payload['written_earlier'] == true;

class _Row {
  _Row(this.event);
  final Event event;
  String? text;
  bool edited = false;
  bool deleted = false;
  final List<Reaction> reactions = [];
}
