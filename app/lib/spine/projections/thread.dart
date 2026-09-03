// The thread projection: what Chat renders. Every row is one spine event; edits, deletes,
// reactions and read markers fold into the row they point at and never appear as rows of
// their own. Rebuilt from the log alone; the golden test replays it.
import '../event.dart';
import '../types.dart';

enum Delivery {
  /// Minted here, not yet accepted by the host.
  waiting,

  /// Accepted (seq assigned) but the partner has not read past it.
  sent,

  /// The partner's read marker covers it.
  read,
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

/// Builds the thread from the log. Linear in the number of events.
ThreadState projectThread(List<Event> events, {Person? me}) {
  final rows = <String, _Row>{};
  final order = <String>[];
  final readUpto = <Person, int>{};
  for (final e in events) {
    final spec = kEventTypeById[e.type];
    if (spec == null) continue;
    switch (e.type) {
      case 'message_edit':
        final t = e.payload['target'] as String?;
        final row = t == null ? null : rows[t];
        if (row != null && row.event.author == e.author) {
          row.text = e.payload['text'] as String?;
          row.edited = true;
        }
        continue;
      case 'message_delete':
        final t = e.payload['target'] as String?;
        final row = t == null ? null : rows[t];
        if (row != null && row.event.author == e.author) row.deleted = true;
        continue;
      case 'reaction':
        final t = e.payload['target'] as String?;
        final row = t == null ? null : rows[t];
        if (row != null) {
          row.reactions.removeWhere((r) => r.by == e.author && r.feelingId == e.payload['feeling_id']);
          row.reactions.add(Reaction(by: e.author, feelingId: e.payload['feeling_id'] as String, eventId: e.id, at: e.ts));
        }
        continue;
      case 'read_marker':
        final upto = e.payload['upto_seq'];
        if (upto is int) {
          final prev = readUpto[e.author] ?? 0;
          if (upto > prev) readUpto[e.author] = upto;
        }
        continue;
    }
    if (!spec.rowInThread) continue;
    rows[e.id] = _Row(e);
    order.add(e.id);
  }
  final items = <ThreadItem>[];
  final byId = <String, ThreadItem>{};
  for (final id in order) {
    final r = rows[id]!;
    final e = r.event;
    final other = e.author.other;
    final theirRead = readUpto[other] ?? 0;
    final delivery = e.seq == null
        ? Delivery.waiting
        : (e.seq! <= theirRead ? Delivery.read : Delivery.sent);
    Event? replyTo;
    final rt = e.payload['reply_to'];
    if (rt is String) replyTo = rows[rt]?.event;
    final arrived = e.seq == null ? null : _arrivalHint(e);
    final item = ThreadItem(
      event: e,
      text: r.text ?? (e.payload['text'] as String?) ?? (e.payload['caption'] as String?),
      edited: r.edited,
      deleted: r.deleted,
      reactions: List.unmodifiable(r.reactions),
      replyTo: replyTo,
      delivery: delivery,
      writtenEarlier: arrived ?? false,
    );
    items.add(item);
    byId[id] = item;
  }
  return ThreadState(items: items, readUpto: readUpto, byId: byId);
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
