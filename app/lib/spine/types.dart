// The event type registry. docs/EVENT_TYPES.md lists the same seventeen types; the schema test
// fails if the two disagree. Adding a type: one entry here and one renderer in
// regions/chat/renderers/. Nothing else.

/// How a type is announced when it arrives from the partner.
enum Notify {
  /// Sound, preview, allowed to interrupt (honouring quiet hours).
  interruptive,

  /// Ambient surfaces update, no sound.
  quiet,

  /// Never announced.
  none,
}

/// What of the payload is searchable and how the type is filtered.
class SearchSpec {
  const SearchSpec({this.textFields = const [], this.facets = const [], this.excluded = false});

  /// Payload keys whose text is indexed.
  final List<String> textFields;

  /// Facet names this type belongs to in Moments filters (e.g. 'media', 'feeling').
  final List<String> facets;

  /// Excluded from search entirely (read markers, deletes).
  final bool excluded;
}

class EventTypeSpec {
  const EventTypeSpec({
    required this.id,
    required this.required,
    required this.optional,
    required this.notify,
    required this.search,
    required this.renderer,
    this.refKeys = const [],
    this.blobKeys = const [],
    this.rowInThread = true,
  });

  final String id;

  /// Required payload keys.
  final List<String> required;

  /// Optional payload keys.
  final List<String> optional;
  final Notify notify;
  final SearchSpec search;

  /// The renderer id in regions/chat/renderers (one per type).
  final String renderer;

  /// Payload keys whose values are event ids (become `refs`).
  final List<String> refKeys;

  /// Payload keys whose values are blob hashes (become `blobs`).
  final List<String> blobKeys;

  /// Whether the type appears as its own row in the thread. Reactions and read markers do not.
  final bool rowInThread;

  /// Checks a payload against the spec; returns the first problem or null.
  String? validate(Map<String, dynamic> payload) {
    for (final k in required) {
      if (!payload.containsKey(k) || payload[k] == null) return '$id: missing $k';
    }
    for (final k in payload.keys) {
      if (!required.contains(k) && !optional.contains(k)) return '$id: unknown key $k';
    }
    return null;
  }
}

const List<EventTypeSpec> kEventTypes = [
  EventTypeSpec(
    id: 'message',
    required: ['text'],
    optional: ['reply_to', 'written_earlier'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['text'], facets: ['message']),
    renderer: 'note',
    refKeys: ['reply_to'],
  ),
  EventTypeSpec(
    id: 'photo',
    required: ['blob', 'w', 'h'],
    optional: ['caption', 'reply_to', 'mime'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['caption'], facets: ['media', 'photo']),
    renderer: 'print',
    refKeys: ['reply_to'],
    blobKeys: ['blob'],
  ),
  EventTypeSpec(
    id: 'video',
    required: ['blob', 'poster_blob', 'duration_ms', 'w', 'h'],
    optional: ['caption', 'mime'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['caption'], facets: ['media', 'video']),
    renderer: 'print_tab',
    blobKeys: ['blob', 'poster_blob'],
  ),
  EventTypeSpec(
    id: 'voice_note',
    required: ['blob', 'duration_ms', 'waveform'],
    optional: ['mime'],
    notify: Notify.interruptive,
    search: SearchSpec(facets: ['media', 'voice']),
    renderer: 'strip_wave',
    blobKeys: ['blob'],
  ),
  EventTypeSpec(
    id: 'reaction',
    required: ['target', 'feeling_id'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(facets: ['feeling']),
    renderer: 'stuck_object',
    refKeys: ['target'],
    rowInThread: false,
  ),
  EventTypeSpec(
    id: 'message_edit',
    required: ['target', 'text'],
    optional: [],
    notify: Notify.none,
    search: SearchSpec(textFields: ['text'], facets: ['message']),
    renderer: 'edit_mark',
    refKeys: ['target'],
    rowInThread: false,
  ),
  EventTypeSpec(
    id: 'message_delete',
    required: ['target'],
    optional: [],
    notify: Notify.none,
    search: SearchSpec(excluded: true),
    renderer: 'stub',
    refKeys: ['target'],
    rowInThread: false,
  ),
  EventTypeSpec(
    id: 'read_marker',
    required: ['upto_seq'],
    optional: [],
    notify: Notify.none,
    search: SearchSpec(excluded: true),
    renderer: 'ink_dries',
    rowInThread: false,
  ),
  EventTypeSpec(
    id: 'feeling',
    required: ['feeling_id', 'intensity'],
    optional: ['hold_ms'],
    notify: Notify.interruptive,
    search: SearchSpec(facets: ['feeling']),
    renderer: 'object_landing',
  ),
  EventTypeSpec(
    id: 'state_declared',
    required: ['signal', 'value'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['value'], facets: ['state']),
    renderer: 'margin_note',
  ),
  EventTypeSpec(
    id: 'state_passive',
    required: ['signal', 'value'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(facets: ['state']),
    renderer: 'margin_mark',
  ),
  EventTypeSpec(
    id: 'date_event',
    required: ['date_id', 'action', 'title'],
    optional: ['when', 'place', 'rating', 'note'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title', 'place', 'note'], facets: ['us', 'dates']),
    renderer: 'ticket_stub',
  ),
  EventTypeSpec(
    id: 'todo_event',
    required: ['todo_id', 'action', 'text'],
    optional: ['assignee'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['text'], facets: ['us', 'todos']),
    renderer: 'list_line',
  ),
  EventTypeSpec(
    id: 'milestone',
    required: ['milestone_id', 'kind', 'title', 'date', 'yearly'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title'], facets: ['us', 'calendar', 'milestone']),
    renderer: 'stamped_card',
  ),
  EventTypeSpec(
    id: 'ritual_kept',
    required: ['ritual_id', 'title', 'kept_at'],
    optional: ['note'],
    notify: Notify.none,
    search: SearchSpec(textFields: ['title', 'note'], facets: ['us', 'rituals']),
    renderer: 'tally_mark',
  ),
  EventTypeSpec(
    id: 'ping',
    required: ['schedule_id', 'text', 'fires_at'],
    optional: ['feeling_id', 'repeat'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['text'], facets: ['ping']),
    renderer: 'folded_clock',
  ),
  EventTypeSpec(
    id: 'feeling_authored',
    required: ['feeling_id', 'name', 'family', 'colour', 'object_asset', 'haptic', 'sound', 'retired'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['name'], facets: ['feeling']),
    renderer: 'new_feeling_card',
  ),
];

final Map<String, EventTypeSpec> kEventTypeById = {for (final t in kEventTypes) t.id: t};

EventTypeSpec specOf(String type) {
  final s = kEventTypeById[type];
  if (s == null) throw ArgumentError('unknown event type $type');
  return s;
}
