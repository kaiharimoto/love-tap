# SIGNALS

Partner-state signals: the channels that make one person's inner and outer situation continuously
legible to the other. Fourteen signals in four kinds. Each has its own source on each platform and
its own material rendering; none is collapsed into a mood blob or a coloured dot.

Declared signals are `state_declared` events. Passive signals are `state_passive` events, emitted
only on a change of state (rate-limited to one per signal per five minutes) so the spine records
transitions rather than ticks. Where the PWA has no source, the signal is **freshness-faded**: the
last known value is shown with its ink drying (fresh → dull → faded over 0 / 2 h / 24 h), and the
partner strip says how old it is. A faded signal is still a rendered signal, not a blank.

## Where they show

- **The partner strip**: a torn strip of the partner's current paper, in their ink, at the top of
  every region. It carries every signal below at once, compactly.
- **Pulse**: the strip expanded into a full sheet, with the need and energy dials as physical folds.
- **Ambient surfaces**: widget / standing notification (glanceable), notification (interruptive),
  pocket pulse (peripheral).

## The table

| # | id | kind | values | Android source | PWA source or substitute | material rendering |
|---|---|---|---|---|---|---|
| 1 | `mood` | declared | bright, calm, tender, restless, low, flat | picked on Pulse | picked on Pulse | **the paper stock** the strip is torn from: bright → legal yellow; calm → lined; tender → index card; restless → sticky note; low → graph blue-grey; flat → loose leaf |
| 2 | `status_line` | declared | free text, one line | typed on Pulse | typed on Pulse | a line in the partner's hand across the strip |
| 3 | `availability` | declared | open, heads_down, asleep | picked on Pulse | picked on Pulse | strip orientation: open → face up; heads_down → folded in half with "back at …" on the outside; asleep → turned face down |
| 4 | `need` | need/energy | 0–4 | dial on Pulse | dial on Pulse | how far the strip's corner is folded over toward you (0 flat → 4 fully over); at 3+ the desk shows their sheet peeking from under yours on every region |
| 5 | `energy` | need/energy | 0–4 | dial on Pulse | dial on Pulse | pen pressure of their handwriting on the strip (0 faint pencil → 4 hard biro) and the sheet's brightness variant |
| 6 | `battery` | passive | 0–100 | BatteryManager | freshness-faded (no Battery API in Safari) | a pencil in the margin, worn to a stub as it drains; under 15 % a red-pen ring around the stub |
| 7 | `charging` | passive | true/false | BatteryManager | freshness-faded | a small plug-and-cord doodle beside the pencil |
| 8 | `last_active` | passive | minutes since the screen was last on with the app open | screen-on and app lifecycle | Page Visibility + visibilitychange | ink wetness on the strip: fresh glossy (specular from the rig) → dull → faded |
| 9 | `local_hour` | passive | 0–23 in their zone | device clock + zone | `Date` + zone | the strip is rendered under **their** light condition: daylight or dusk with the lamp |
| 10 | `ringer` | passive | normal, vibrate, silent | AudioManager ringer mode | freshness-faded | silent → a piece of tape over the strip's corner; vibrate → a pencil squiggle; normal → nothing |
| 11 | `moving` | passive | still, walking, riding | ActivityRecognition / accelerometer | DeviceMotion (after permission) or faded | walking → the strip sits askew and trembles once when it changes; riding → a faint pencil arrow |
| 12 | `network` | passive | wifi, cellular, offline | ConnectivityManager | `navigator.onLine` + Network Information where present, else faded | cellular → a small radio-mast doodle (they are out); offline → the strip's ink stops updating and a "last seen" appears |
| 13 | `place` | place | home, work, out, travelling | geofences the person set on Settings (coarse, on-device) | picked on Pulse; geolocation coarse geofence after permission | a DeskStamp stamp on the strip's corner: HOME · WORK · OUT · AWAY |
| 14 | `at_home` | place | true/false | Wi-Fi SSID equals the one marked "home" | freshness-faded | a house doodle in the margin when home |

Kinds: declared 3 · need/energy 2 · passive 7 · place 2. Floors: 3 / 2 / 3 / 1.

## Propagation

A signal change is one event. It travels the same channel as messages, updates the partner strip on
every region, updates the ambient surfaces (Android widget and standing notification; PWA standing
notification via a push carrying only `kind` and `sender`, after which the client fetches the event
over the channel), and is perceptible with the app closed. It never nags: no signal change makes a
sound unless the receiving person scheduled a ping for it.
