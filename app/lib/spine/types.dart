// The event type registry. docs/EVENT_TYPES.md lists the same seventeen types; the schema test
// fails if the two disagree.
//
// Adding a type is one entry here and one renderer in regions/chat/renderers.dart, and
// app/test/thread_types_test.dart holds both ends of that to it: every renderer named here has to
// exist, every renderer there has to be named here, and every type has to read as a sentence in
// search and in a notification. For most of this build's life the field below named a directory
// that did not exist and no code read it, while the thread and search each kept their own copy of
// a switch on the type — so a type added to one and forgotten in the other rendered properly in
// the thread and as a bare id in search. Hence the tests.

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
    required this.said,
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

  /// What this kind of event is, said the way one of the two of them would say it: `a picture`,
  /// `their voice`, `a day that matters`. The id is for the log; this is what reaches the glass
  /// wherever a kind of event is named to a person -- the interrupt matrix in settings first.
  ///
  /// It is REQUIRED, and it lives here rather than in a switch next to the screen that shows it,
  /// because that switch had eighteen types to know about and knew seventeen: `passed_on` fell
  /// through to `type.replaceAll('_', ' ')` and `05_settings_interrupt` carried the run `passed
  /// on`, a registry id with its underscore swapped for a space. A type cannot be added now
  /// without saying what it is.
  final String said;

  /// Required payload keys.
  final List<String> required;

  /// Optional payload keys.
  final List<String> optional;
  final Notify notify;
  final SearchSpec search;

  /// The renderer id in regions/chat/renderers.dart (one per type; the map is keyed by this).
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

    said: 'something written',
    required: ['text'],
    optional: ['reply_to', 'written_earlier'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['text'], facets: ['message']),
    renderer: 'note',
    refKeys: ['reply_to'],
  ),
  EventTypeSpec(
    id: 'photo',

    said: 'a picture',
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

    said: 'something to watch',
    required: ['blob', 'poster_blob', 'duration_ms', 'w', 'h'],
    optional: ['caption', 'mime'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['caption'], facets: ['media', 'video']),
    renderer: 'print_tab',
    blobKeys: ['blob', 'poster_blob'],
  ),
  EventTypeSpec(
    id: 'voice_note',

    said: 'their voice',
    required: ['blob', 'duration_ms', 'waveform'],
    optional: ['mime'],
    notify: Notify.interruptive,
    search: SearchSpec(facets: ['media', 'voice']),
    renderer: 'strip_wave',
    blobKeys: ['blob'],
  ),
  EventTypeSpec(
    id: 'reaction',

    said: 'an answer to something of yours',
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

    said: 'a change to something already said',
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

    said: 'something taken back',
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

    said: 'them catching up',
    required: ['upto_seq'],
    optional: [],
    notify: Notify.none,
    search: SearchSpec(excluded: true),
    renderer: 'ink_dries',
    rowInThread: false,
  ),
  EventTypeSpec(
    id: 'feeling',

    said: 'a feeling',
    required: ['feeling_id', 'intensity'],
    optional: ['hold_ms'],
    notify: Notify.interruptive,
    search: SearchSpec(facets: ['feeling']),
    renderer: 'object_landing',
  ),
  EventTypeSpec(
    id: 'state_declared',

    said: 'something they say about themselves',
    required: ['signal', 'value'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['value'], facets: ['state']),
    renderer: 'margin_note',
  ),
  EventTypeSpec(
    id: 'state_passive',

    said: 'something their phone notices',
    required: ['signal', 'value'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(facets: ['state']),
    renderer: 'margin_mark',
  ),
  EventTypeSpec(
    id: 'date_event',

    said: 'a date moving',
    required: ['date_id', 'action', 'title'],
    optional: ['when', 'place', 'verdict', 'note'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title', 'place', 'note', 'verdict'], facets: ['us', 'dates']),
    renderer: 'ticket_stub',
  ),
  EventTypeSpec(
    id: 'todo_event',

    said: 'the list moving',
    required: ['todo_id', 'action', 'text'],
    optional: ['assignee'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['text'], facets: ['us', 'todos']),
    renderer: 'list_line',
  ),
  EventTypeSpec(
    id: 'milestone',

    said: 'a day that matters',
    required: ['milestone_id', 'kind', 'title', 'date', 'yearly'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title'], facets: ['us', 'calendar', 'milestone']),
    renderer: 'stamped_card',
  ),
  EventTypeSpec(
    id: 'ritual_kept',

    said: 'one of the things you keep',
    required: ['ritual_id', 'title', 'kept_at'],
    optional: ['note'],
    notify: Notify.none,
    search: SearchSpec(textFields: ['title', 'note'], facets: ['us', 'rituals']),
    renderer: 'tally_mark',
  ),
  EventTypeSpec(
    id: 'passed_on',

    said: 'something handed on to you',
    required: ['item_id', 'action', 'title', 'kind'],
    optional: ['note'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title', 'note'], facets: ['us', 'shelf']),
    renderer: 'shelf_card',
  ),
  EventTypeSpec(
    id: 'ping',

    said: 'a note set to arrive later',
    required: ['schedule_id', 'text', 'fires_at'],
    optional: ['feeling_id', 'repeat'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['text'], facets: ['ping']),
    renderer: 'folded_clock',
  ),
  EventTypeSpec(
    id: 'feeling_authored',

    said: 'a feeling one of you made',
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
