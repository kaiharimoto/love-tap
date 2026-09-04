# EVENT_TYPES

The single spine holds exactly one kind of row: an **event**. Everything either person does lands
here, in host order, attributed and timestamped. Every region is a view over this list. There is no
other store. `app/lib/spine/types.dart` is the registry; `app/test/spine_schema_test.dart` asserts
that the registry and this document list the same types.

## Envelope (every event)

| field | type | meaning |
|---|---|---|
| `id` | ULID, 26 chars | minted by the author's device; globally unique; sortable by author time |
| `seq` | int or null | host-assigned monotonic sequence; the thread order; null until the host has accepted it |
| `author` | `noor` \| `teo` | one of the two people, always |
| `device` | `android` \| `pwa` | which of the two devices minted it |
| `ts` | int, ms since epoch | the author's wall clock at minting |
| `type` | string | one of the registry ids below |
| `refs` | list of ids | events this one points at (reply target, reaction target, edit target, …) |
| `blobs` | list of sha256 | content-addressed media this event needs; transferred on the same channel |
| `payload` | object | per-type fields, below |

Ordering: the thread is ordered by `seq`. An event authored offline gets its `seq` when it reaches
the host, so it appears where it *arrived*, carrying its authored `ts` so the note can say "written
earlier". Two devices can never disagree about order because only the host assigns `seq`.

Not events (ephemeral frames on the transport, never persisted): typing, presence heartbeat,
cursor acknowledgement, blob transfer progress.

## The registry

| # | type | payload | thread rendering | notification | search |
|---|---|---|---|---|---|
| 1 | `message` | `text`, `reply_to?` | a note in the author's hand on their paper; a reply is pinned over a torn strip of the note it answers | sound + first line, interruptive | full text (FTS) |
| 2 | `photo` | `blob`, `w`, `h`, `caption?`, `reply_to?` | a print taped at two corners, caption underneath in hand | "a photo", interruptive | caption text; media facet |
| 3 | `video` | `blob`, `poster_blob`, `duration_ms`, `w`, `h`, `caption?` | a print with a tape tab and a pencilled duration; tap opens the viewer | "a video", interruptive | caption text; media facet |
| 4 | `voice_note` | `blob`, `duration_ms`, `waveform` (list of 0–1) | a strip with the waveform drawn in pencil, a small play mark | "a voice note", interruptive | media facet, duration; no transcript |
| 5 | `reaction` | `target`, `feeling_id` | the feeling object stuck to the target note, never a row | quiet (no sound) | by feeling, by family |
| 6 | `message_edit` | `target`, `text` | the target's text replaced, with a small pencil "edited" in the margin; the original stays in the spine | none | latest text indexed, original de-indexed |
| 7 | `message_delete` | `target` | the target becomes a torn stub reading "took this back", in the author's hand | none | excluded |
| 8 | `read_marker` | `upto_seq` | a mark on the last read note (the ink dries), never a row | none | excluded |
| 9 | `feeling` | `feeling_id`, `intensity` (0–1), `hold_ms` | the object landing on the desk between notes, shadow first | object + haptic pattern (PWA: page rhythm), interruptive | by feeling, by family, by intensity |
| 10 | `state_declared` | `signal`, `value` | a marginal note in the author's hand ("heads down until 6") | ambient surfaces update; a mood change is quiet | by signal |
| 11 | `state_passive` | `signal`, `value` | coalesced: one margin mark per meaningful transition per hour ("phone died"), otherwise folded into the partner strip only | ambient surfaces update | by signal |
| 12 | `date_event` | `date_id`, `action` (planned/scheduled/done/rated/remembered), `title`, `when?`, `place?`, `rating?`, `note?` | a ticket-stub note; a rating is pencil stars on the stub | per action; quiet for planned, interruptive for scheduled | title, place, note |
| 13 | `todo_event` | `todo_id`, `action` (added/assigned/done/reopened/removed), `text`, `assignee?` | a checklist line torn from a list, ticked in the author's ink when done | quiet; interruptive when assigned to you | text |
| 14 | `milestone` | `milestone_id`, `kind` (anniversary/first/custom), `title`, `date`, `yearly` | a stamped card | on the day, interruptive, via a `ping` scheduled by a person | title |
| 15 | `ritual_kept` | `ritual_id`, `title`, `kept_at`, `note?` | a small tally mark in the margin; never a count, never a run | none | title, note |
| 16 | `ping` | `schedule_id`, `text`, `feeling_id?`, `fires_at`, `repeat?` | a folded note with a clock scribble, unfolding when it fires | at `fires_at`, interruptive, honouring quiet hours | text |
| 17 | `feeling_authored` | `feeling_id`, `name`, `family`, `colour`, `object_asset`, `haptic`, `sound`, `retired` | a card announcing a new feeling in the author's hand | quiet | name |

Seventeen types. The floor is fourteen.

## Adding an eighteenth

1. Add one entry to `kEventTypes` in `app/lib/spine/types.dart` (id, payload codec, search fields,
   notification treatment).
2. Add one renderer under `app/lib/regions/chat/renderers.dart`, registered by id.

Nothing else changes: persistence is schema-less per type (payload is JSON), search fields are
declared by the registry entry, Moments filters by `type` generically, and notifications read the
registry. `app/test/spine_schema_test.dart` fails if the registry and this table disagree.

## Projections (derived, rebuildable)

Current state (who is where, what is unread, the latest of each signal, the to-do list, the date
list) is a projection replayed from the spine. `app/test/spine_replay_golden_test.dart` replays the
seeded year and compares every region's view to a golden; a projection that cannot be rebuilt from
the log alone fails the build.
