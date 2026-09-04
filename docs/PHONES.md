# The two phones

A mirror of the setup checklist each phone shows on its first run (`app/lib/setup/checklist.dart`),
written out here so it can be read before either phone has the app on it. Nothing in this document
is a step the app cannot see for itself: every line below corresponds to a step that ticks off when
the app observes the thing happening, and stays unticked otherwise.

There is no account, no server, and nobody else on the wire. The two phones talk to each other over
a tailnet with two nodes on it, and that is the whole system.

---

## Before either phone

One tailnet, two nodes, nothing else joined to it. The Android phone is the host: it holds the log,
serves the certificate, and reads out the six words. The iPhone is the client. Either phone can be
replaced later without the other one being reinstalled — Settings has "replace one of the phones".

A key expires. Tailscale auth keys are good for at most 90 days, and a node whose key has expired
drops off the tailnet silently: the notes simply stop arriving, and nothing on either screen says
why. Re-authenticate the node from the Tailscale app before that happens; the setup list's
"put this phone on the tailnet" step un-ticks itself when the address goes away, which is the
app's only way of telling you.

---

## The Android phone

1. **Put this phone on the tailnet.** The same private network as the other phone, and nothing else
   on it.
   *Ticks when: the transport reports an address on the tailnet.*
2. **Trust the certificate the other phone holds.** So nothing between the two of you can read what
   goes across.
   *Ticks when: a connection completes with a certificate this device verified.*
3. **Read the six words off the other phone.** Say them out loud in the same room. They are only
   good once.
   *Ticks when: pairing completes and both device ids are recorded.*
4. **Let it interrupt you.** You choose which kinds, later, in settings. This only opens the door.
   *Ticks when: the notification permission is granted.*
5. **Write the first thing.** Anything. It goes to one person.
   *Ticks when: an event authored on this phone is in the log.*
6. **Wait for theirs to arrive.**
   *Ticks when: an event authored by the other person is in the log.*

## The iPhone

An iPhone needs two things Android does not: the app has to leave Safari, and the certificate goes
in through a profile rather than a prompt.

1. **Add it to the home screen.** Share, then add to home screen. It will not hold on to anything
   until you do — a PWA in a Safari tab has its storage evicted.
   *Ticks when: the page is running in standalone display mode.*
2. **Put this phone on the tailnet.**
   *Ticks when: the transport reports an address on the tailnet.*
3. **Install the profile the other phone is serving.** Open its address in Safari, take the profile,
   then trust it in Settings → General → About → Certificate Trust Settings. iOS will not offer the
   trust switch until the profile is installed, and will not install a profile from a page opened
   inside the app.
   *Ticks when: a connection completes with a certificate this device verified.*
4. **Read the six words off the other phone.**
   *Ticks when: pairing completes.*
5. **Let it interrupt you.** An iPhone only offers this once the app is on the home screen.
   *Ticks when: the notification permission is granted.*
6. **Write the first thing.**
   *Ticks when: an event authored on this phone is in the log.*
7. **Wait for theirs to arrive.**
   *Ticks when: an event authored by the other person is in the log.*

---

## What the iPhone does not have

**Haptics.** There is no vibration API in a PWA on iOS, and there is not going to be one. The
substitute is not an apology: a feeling arriving moves the page itself — the whole surface shifts on
the same rhythm the Android phone would buzz on, with the feeling's own sound underneath it. The
notation is the same in both places (`docs/FEELINGS.md`), so "held" has the same shape whichever
phone you are holding.

**Background delivery of content.** A Web Push payload carries the event kind and who sent it, and
nothing else. The note itself is fetched over the tailnet when the app is opened. This is not a
limitation being worked around — it is the rule: nothing of what they wrote travels by any path but
the one wire between the two phones.

---

## Verified

| what | on | date |
|---|---|---|
| Android build installed and run in the AVD | android-34 aosp_atd x86_64, no KVM | — |
| PWA run in Playwright WebKit | WebKit 26.5 | 2026-09-03 |
| Pairing across two tailnet nodes | — | — |
| Real iPhone, added to home screen | — | — |
| Real Android phone | — | — |

A dash means it has not been done yet, not that it failed. The rows are filled in on the day the
thing actually happens, by the person it happened to.
