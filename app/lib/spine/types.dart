// The event type registry. docs/EVENT_TYPES.md lists the same seventeen types; the schema test
// fails if the two disagree.
//
// Adding a type is one entry here and one renderer in thread/renderers.dart, and
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
    required this.required,
    required this.optional,
    required this.notify,
    required this.search,
    required this.renderer,
    required this.noun,
    required this.announced,
    this.pushed,
    this.lens,
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

  /// The renderer id in thread/renderers.dart (one per type; the map is keyed by this).
  final String renderer;

  /// What a phone in a pocket says when one of these arrives and the app is shut, in the words one
  /// of them would use: 'wrote something', 'left their voice'. Null for a kind that never
  /// announces itself.
  ///
  /// Here rather than in the service worker. The worker had a table of its own — it is JavaScript
  /// and cannot import this file — and the two drifted: a word for a kind the registry says never
  /// announces itself, and none for three that do. The app writes this table into its own store
  /// at startup and the worker reads it there, so there is one list and the worker keeps no
  /// per-type knowledge at all.
  final String? pushed;

  /// What one of these is, in the words a person would use about it: 'a date', 'the list', 'a
  /// photograph'. Search says "found as a date" with it when the words are in the type rather
  /// than in the line.
  final String noun;

  /// What it reads as when it arrives, on the row in Settings that says whether it may interrupt.
  /// A different register from [noun] — what landed, not what it is.
  ///
  /// Both used to be switches, one in the search page and one in the settings region, so a new
  /// type had two more shared files to be added to and read as its own bare id in both until it
  /// was. They are declared here with the type now, which is where the promise says a type is
  /// declared.
  final String announced;

  /// Which of Moments' three piles this event belongs in: 'media', 'felt', 'happened', or null
  /// for the kinds that are not kept there at all.
  ///
  /// It was a pair of sets written into the region, and the "what happened" one named four of the
  /// five kinds of thing that happen, so a book one of them handed the other appeared in no lens.
  /// The first fix asked the search facets, which put a lens name into the search index: 'happened'
  /// is a word two people write to each other, and typing it returned every date, ritual,
  /// milestone and shelf card in the year as a keyword hit. A lens is not a search facet, so it is
  /// its own field.
  final String? lens;

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
    noun: 'written',
    announced: 'something written',
    pushed: 'wrote something',
    refKeys: ['reply_to'],
  ),
  EventTypeSpec(
    id: 'photo',
    required: ['blob', 'w', 'h'],
    optional: ['caption', 'reply_to', 'mime'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['caption'], facets: ['media', 'photo']),
    renderer: 'print',
    noun: 'a photograph',
    announced: 'a picture',
    pushed: 'sent a picture',
    lens: 'media',
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
    noun: 'a video',
    announced: 'something to watch',
    pushed: 'sent something to watch',
    lens: 'media',
    blobKeys: ['blob', 'poster_blob'],
  ),
  EventTypeSpec(
    id: 'voice_note',
    required: ['blob', 'duration_ms', 'waveform'],
    optional: ['mime'],
    notify: Notify.interruptive,
    search: SearchSpec(facets: ['media', 'voice']),
    renderer: 'strip_wave',
    noun: 'something said',
    announced: 'their voice',
    pushed: 'left their voice',
    lens: 'media',
    blobKeys: ['blob'],
  ),
  EventTypeSpec(
    id: 'reaction',
    required: ['target', 'feeling_id'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(facets: ['feeling']),
    renderer: 'stuck_object',
    noun: 'a reaction',
    announced: 'an answer to something of yours',
    pushed: 'answered something of yours',
    lens: 'felt',
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
    noun: 'a change',
    announced: 'a change to something already said',
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
    noun: 'something taken back',
    announced: 'something taken back',
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
    noun: 'them catching up',
    announced: 'them catching up',
    rowInThread: false,
  ),
  EventTypeSpec(
    id: 'feeling',
    required: ['feeling_id', 'intensity'],
    optional: ['hold_ms'],
    notify: Notify.interruptive,
    search: SearchSpec(facets: ['feeling']),
    renderer: 'object_landing',
    noun: 'a feeling',
    announced: 'a feeling',
    pushed: 'is holding something out',
    lens: 'felt',
  ),
  EventTypeSpec(
    id: 'state_declared',
    required: ['signal', 'value'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['value'], facets: ['state']),
    renderer: 'margin_note',
    noun: 'a state',
    announced: 'something they say about themselves',
    pushed: 'said how they are',
  ),
  EventTypeSpec(
    id: 'state_passive',
    required: ['signal', 'value'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(facets: ['state']),
    renderer: 'margin_mark',
    noun: 'something their phone noticed',
    announced: 'something their phone notices',
    pushed: 'their phone noticed something',
  ),
  EventTypeSpec(
    id: 'date_event',
    required: ['date_id', 'action', 'title'],
    optional: ['when', 'place', 'verdict', 'note'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title', 'place', 'note', 'verdict'], facets: ['us', 'dates']),
    renderer: 'ticket_stub',
    noun: 'a date',
    announced: 'a date moving',
    pushed: 'moved something in dates',
    lens: 'happened',
  ),
  EventTypeSpec(
    id: 'todo_event',
    required: ['todo_id', 'action', 'text'],
    optional: ['assignee'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['text'], facets: ['us', 'todos']),
    renderer: 'list_line',
    noun: 'the list',
    announced: 'the list moving',
    pushed: 'moved something on the list',
  ),
  EventTypeSpec(
    id: 'milestone',
    required: ['milestone_id', 'kind', 'title', 'date', 'yearly'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title'], facets: ['us', 'calendar', 'milestone']),
    renderer: 'stamped_card',
    noun: 'a milestone',
    announced: 'a day that matters',
    pushed: 'marked a day',
    lens: 'happened',
  ),
  EventTypeSpec(
    id: 'ritual_kept',
    required: ['ritual_id', 'title', 'kept_at'],
    optional: ['note'],
    notify: Notify.none,
    search: SearchSpec(textFields: ['title', 'note'], facets: ['us', 'rituals']),
    renderer: 'tally_mark',
    noun: 'a ritual',
    announced: 'one of the things you keep',
    lens: 'happened',
  ),
  EventTypeSpec(
    id: 'passed_on',
    required: ['item_id', 'action', 'title', 'kind'],
    optional: ['note'],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['title', 'note'], facets: ['us', 'shelf']),
    renderer: 'shelf_card',
    noun: 'something passed on',
    announced: 'something passed between you',
    pushed: 'passed something on',
    lens: 'happened',
  ),
  EventTypeSpec(
    id: 'ping',
    required: ['schedule_id', 'text', 'fires_at'],
    optional: ['feeling_id', 'repeat'],
    notify: Notify.interruptive,
    search: SearchSpec(textFields: ['text'], facets: ['ping']),
    renderer: 'folded_clock',
    noun: 'a note set to arrive later',
    announced: 'a note set to arrive later',
    pushed: 'is asking for you',
  ),
  EventTypeSpec(
    id: 'feeling_authored',
    required: ['feeling_id', 'name', 'family', 'colour', 'object_asset', 'haptic', 'sound', 'retired'],
    optional: [],
    notify: Notify.quiet,
    search: SearchSpec(textFields: ['name'], facets: ['feeling']),
    renderer: 'new_feeling_card',
    noun: 'a feeling one of you made',
    announced: 'a feeling one of you made',
    pushed: 'made a new feeling',
    lens: 'happened',
  ),
];

final Map<String, EventTypeSpec> kEventTypeById = {for (final t in kEventTypes) t.id: t};

EventTypeSpec specOf(String type) {
  final s = kEventTypeById[type];
  if (s == null) throw ArgumentError('unknown event type $type');
  return s;
}
