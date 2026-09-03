# VOICE

How anything in the app is allowed to speak. Every displayed string lives in `app/lib/voice/strings.dart`
and passes `tools/lint/strings.py`.

## Rules

1. The app has no name and never says one. Nothing refers to "the app", "this app", or a product.
2. No exclamation marks. Anywhere. Not in setup, not in errors, not in a notification.
3. No one is a "user". The two people are Noor and Teo, or "you" spoken as a person would, never as
   an account.
4. No cheerfulness that belongs to marketing: no "Oops", "Welcome", "Awesome", "Great", "Let's",
   "Get started", "You're all set", "Something went wrong".
5. Lower case unless it is a name or the start of a handwritten line that would be capitalised by
   the person writing it. Sentences end with full stops or trail off. Fragments are fine.
6. Errors are plain statements of what is true and what will happen: no apology, no reassurance.
7. Notifications name the person and the thing: the thing is the sender's, not the app's.
8. The rituals surface never says streak, run, best, reset, broken, missed, or a count.
9. No system emoji, ever. Objects are drawn or rendered.
10. Naming Tailscale, the Play Store, the App Store, Safari, or Settings is allowed in setup.

## Registers

**Notes on the desk** (empty states, setup, first run): written as the paper the two people would
leave, in one of their hands or in DeskStamp when it is furniture.

**Margins** (system facts inside the thread): pencil, small, factual. "written earlier". "took this back".

**Stamps** (labels, dates, tabs): DeskStamp, upper case, one or two words.

**Notifications**: the person's name, the object. Never a summary of the app.

## Examples

### Setup (Android)
- `tailnet_wait` — waiting for a Tailscale address on this phone.
- `tailnet_ok` — this phone is on the tailnet.
- `host_listening` — listening on the tailnet address.
- `partner_first_fetch` — Teo's phone has read from here once.
- `tls_ok` — first secure connection made.
- `pair_show` — read this to Teo, six words:
- `pair_ok` — paired.
- `push_ok` — Teo's phone will hear about things.

### Setup (PWA)
- `open_here` — open this address in Safari, on the same tailnet.
- `profile_install` — install the profile from this page, then trust it under Settings, General, About, Certificate Trust.
- `probe_wait` — checking the secure address…
- `probe_ok` — trusted.
- `add_to_home` — share, then add to home screen.
- `pair_enter` — the six words Noor read out:
- `push_ask` — allow notices so things arrive with the screen off.

### Empty states
- Chat: a blank torn strip, pencil line: `first one's yours.`
- Pulse: `nothing from Teo yet. it will show here.`
- Us / dates: `nowhere planned. that's fine.`
- Us / to-dos: `nothing to do. suspicious.`
- Us / calendar: `no dates that matter yet. add the first.`
- Us / rituals: `nothing kept yet.`
- Moments: `it fills in as it happens.`
- Settings / feelings: `the built-in ones are here. make one below.`
- Search, nothing found: `nothing with that in it.`

### Errors
- `offline_queued` — can't reach Teo's phone. it'll go when it can.
- `host_down` — Noor's phone isn't answering. keeping this until it does.
- `blob_pending` — still fetching the picture.
- `pair_wrong` — those aren't the words. try again.
- `tls_untrusted` — the profile isn't trusted yet.

### Notifications
- message: `Noor` / first line of the note
- photo: `Noor` / `a photo`
- feeling: `a squeeze from Noor`
- state: `Noor: heads down until 6`
- ping (authored): the text the person wrote, in their name
- todo assigned: `Teo left you one: bins`
- date scheduled: `Noor put Thursday in: ferry`

### Margins
- `written earlier`, `edited`, `took this back`, `read`, `sent`, `waiting to send`, `phone died`, `asleep by the clock`
