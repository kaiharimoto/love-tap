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

const WORDS = {
  message: 'wrote something',
  photo: 'sent a picture',
  video: 'sent something to watch',
  voice_note: 'left their voice',
  feeling: 'is holding something out',
  ping: 'is asking for you',
  reaction: 'answered something of yours',
  date_event: 'moved something in dates',
  todo_event: 'moved something on the list',
  milestone: 'marked a day',
  ritual_kept: 'kept it',
  feeling_authored: 'made a new feeling',
};

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
  const said = WORDS[kind] || 'left something';
  event.waitUntil(self.registration.showNotification(from || 'the other phone', {
    body: said,
    // one tag, so a second arrival replaces the first instead of stacking into a pile
    tag: 'from-them',
    renotify: true,
    silent: false,
    requireInteraction: false,
    icon: '../icons/Icon-192.png',
    badge: '../icons/Icon-maskable-192.png',
    data: { kind: kind, from: from },
  }));
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
