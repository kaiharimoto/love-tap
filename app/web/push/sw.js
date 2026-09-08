// The service worker that receives a push while the app is closed.
//
// It is registered at /push/ rather than at the root, so it lives alongside the service worker
// Flutter installs to cache the app rather than fighting it for the scope.
//
// The one rule this file keeps: a push carries the event kind and who sent it, and nothing else.
// There is no text here to show because none was sent. What the notification says is made from
// those two fields alone; the note itself is fetched over the tailnet, by the app, from the other
// phone, when the app is opened. If a payload ever arrives with more in it than kind and from,
// the extra is dropped here as well as never being sent — the rule is kept at both ends.

// What a person allowed, read from the phone's own store rather than from anything in the push.
//
// Every event type declares a treatment and a person can set one per type and a pair of quiet
// hours, and for five cycles nothing read either: a code critic grepped for the two functions
// that answer the question and found no caller outside the file that defines them. The place the
// question is actually asked is here — this is what decides whether the phone in a pocket makes a
// sound — and the answers are already written down in the app's own meta store, so this reads
// them there. No copy, no second table, nothing new to keep in step.
const PROFILE = new URL(self.location.href).searchParams.get('profile') || 'default';

// Wait, buzz, wait, buzz: the pocket's own two beats, in the notation the platform reads. Not a
// feeling's rhythm — the worker does not know which feeling it was and must not — but a knock
// rather than a ringtone.
const ARRIVAL = [0, 45, 70, 30];

function fromTheStore(key) {
  return new Promise((resolve) => {
    let open;
    try {
      open = indexedDB.open('spine_' + PROFILE);
    } catch (_) {
      return resolve(null);
    }
    open.onerror = () => resolve(null);
    open.onsuccess = () => {
      const db = open.result;
      let got;
      try {
        got = db.transaction('meta', 'readonly').objectStore('meta').get(key);
      } catch (_) {
        db.close();
        return resolve(null);
      }
      got.onerror = () => { db.close(); resolve(null); };
      got.onsuccess = () => { db.close(); resolve(got.result || null); };
    };
    // a store that does not exist yet is not an error worth waking anybody over
    open.onupgradeneeded = () => { try { open.transaction.abort(); } catch (_) {} };
  });
}

function readPrefs() {
  return fromTheStore('notify.prefs').then((raw) => {
    try {
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  });
}

/// interrupt | quiet | off, for this kind, at this hour, on this phone.
function treatmentFor(prefs, kind, hour) {
  if (!prefs || !prefs.by_type) return 'interrupt';
  const want = prefs.by_type[kind] || 'quiet';
  if (want !== 'interrupt') return want;
  const from = typeof prefs.quiet_from === 'number' ? prefs.quiet_from : 23;
  const to = typeof prefs.quiet_to === 'number' ? prefs.quiet_to : 7;
  const quiet = from <= to ? (hour >= from && hour < to) : (hour >= from || hour < to);
  return quiet ? 'quiet' : 'interrupt';
}

// What each kind of arrival says, read from the phone's own store rather than kept here.
//
// This file is JavaScript and cannot import the registry, so it used to hold a table of its own —
// and the two drifted: a word for a kind the registry says never announces itself, and none for
// three that do. The app writes the registry's own lines into its meta store at startup and this
// reads them there, so the worker knows nothing per-type and there is one list.
function readWords() {
  return fromTheStore('push.words').then((raw) => {
    try {
      return raw ? JSON.parse(raw) : null;
    } catch (_) {
      return null;
    }
  });
}

self.addEventListener('install', (e) => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (event) => {
  let kind = 'message';
  let from = '';
  try {
    const data = event.data ? event.data.json() : {};
    // only these two are read; anything else in the payload is ignored on purpose
    if (typeof data.kind === 'string') kind = data.kind.slice(0, 32);
    if (typeof data.from === 'string') from = data.from.slice(0, 16);
  } catch (_) {
    // an unreadable payload is still an arrival: say that much and no more
  }
  event.waitUntil((async () => {
    const [prefs, words] = await Promise.all([readPrefs(), readWords()]);
    const said = (words && words[kind]) || 'left something';
    const how = treatmentFor(prefs, kind, new Date().getHours());
    // off means off: nothing is shown, and nothing is counted anywhere for later either
    if (how === 'off') return;
    await self.registration.showNotification(from || 'the other phone', {
      body: said,
      // one tag, so a second arrival replaces the first instead of stacking into a pile
      tag: 'from-them',
      renotify: how === 'interrupt',
      // Felt, not heard. An arrival used to carry the system's own notification sound, which is
      // the one sound on the phone that belongs to every other app as well. What the pocket says
      // is a short rhythm in the app's own hand — the same two-beat the standing line settles on —
      // and nothing else. Which feeling it was is not in the push and never will be: a push
      // carries the kind and who sent it, and the feeling plays in full, in its own rhythm and its
      // own sound, the moment the app is opened.
      silent: true,
      vibrate: how === 'interrupt' ? ARRIVAL : undefined,
      requireInteraction: false,
      icon: '../icons/Icon-192.png',
      badge: '../icons/Icon-maskable-192.png',
      data: { kind: kind, from: from, how: how },
    });
  })());
});

// The standing line: what the other phone is doing, kept up to date while this one sleeps. It is
// the same notification, re-shown, so it never becomes a stack and never carries a count.
self.addEventListener('message', (event) => {
  const m = event.data || {};
  if (m.type !== 'standing') return;
  event.waitUntil(self.registration.showNotification(m.who || '', {
    body: m.line || '',
    tag: 'standing',
    silent: true,
    renotify: false,
    requireInteraction: false,
    icon: '../icons/Icon-192.png',
    data: { standing: true },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const open = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of open) {
      if ('focus' in client) return client.focus();
    }
    if (self.clients.openWindow) return self.clients.openWindow('../');
  })());
});
