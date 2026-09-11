// The PWA's three surfaces.
//
// The one an iPhone will not give a web app is the vibrator, and the substitute for it is not an
// apology: the feeling's own rhythm arrives as its sound and, when the app is open, as the page
// itself moving on that rhythm (feelings/sensation.dart). The pattern is the same pattern in
// either place, so 'held' has the same shape on both phones.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../feelings/builtins.dart';
import '../flags.dart';
import '../spine/event.dart';
import 'ambient.dart';

@JS('Notification.permission')
external JSString? get _permission;

@JS('Notification.requestPermission')
external JSPromise<JSString> _requestPermission();

@JS('navigator.serviceWorker')
external _ServiceWorkerContainer? get _serviceWorker;

@JS('window.isSecureContext')
external JSBoolean? get _isSecureContext;

extension type _ServiceWorkerContainer(JSObject o) implements JSObject {
  external JSPromise<_Registration> register(JSString url, JSObject options);
}

extension type _Registration(JSObject o) implements JSObject {
  external _PushManager? get pushManager;
  external _Worker? get active;
  external JSPromise<JSAny?> showNotification(JSString title, JSObject options);
  external JSPromise<JSArray<_Notification>> getNotifications();
}

extension type _Notification(JSObject o) implements JSObject {
  external JSString get title;
  external JSString get body;
  external JSString get tag;
  external bool get silent;
  external void close();
}

extension type _Worker(JSObject o) implements JSObject {
  external void postMessage(JSAny message);
}

extension type _PushManager(JSObject o) implements JSObject {
  external JSPromise<_Sub?> getSubscription();
  external JSPromise<_Sub> subscribe(JSObject options);
}

extension type _Sub(JSObject o) implements JSObject {
  external JSString get endpoint;
  external JSObject toJSON();
}

@JS('JSON.stringify')
external JSString _stringify(JSAny? value);

@JS('JSON.parse')
external JSObject _parse(JSString text);

/// The options bags these browser APIs take are plain objects, and the cleanest way to hand one
/// over from Dart without a dependency is to write it as JSON and let the engine parse it.
JSObject _opts(Map<String, Object?> fields) => _parse(jsonEncode(fields).toJS);

class _WebAmbient implements Ambient {
  _Registration? _registration;
  bool _allowed = false;

  @override
  bool get allowed => _allowed;

  @override
  Future<void> start() async {
    try {
      _allowed = _permission?.toDart == 'granted';
    } catch (_) {
      _allowed = false;
    }
    final container = _serviceWorker;
    if (container == null) return;
    try {
      // registered under /push/ so it sits beside the worker Flutter installs to cache the app
      // rather than fighting it for the root scope, and carrying the profile so the worker can
      // find this phone's own store: what a person allowed each kind of arrival to do, and the
      // hours nothing may interrupt, are written in the app's meta store, and the worker is where
      // that question is actually asked — it is what decides whether a phone in a pocket makes a
      // sound. A worker cannot be told at push time; it has to be able to look it up.
      _registration = await container
          .register('push/sw.js?profile=${Flags.profile}'.toJS, _opts({'scope': 'push/'}))
          .toDart;
    } catch (_) {
      _registration = null;
    }
  }

  @override
  Future<bool> ask() async {
    try {
      final answer = await _requestPermission().toDart;
      _allowed = answer.toDart == 'granted';
    } catch (_) {
      _allowed = false;
    }
    return _allowed;
  }

  @override
  Future<void> standing(Person who, String line) async {
    if (!_allowed) return;
    final worker = _registration?.active;
    if (worker != null) {
      worker.postMessage(_opts({'type': 'standing', 'who': who.name, 'line': line}));
      return;
    }
    try {
      await _registration?.showNotification(who.name.toJS, _opts({
        'body': line,
        'tag': 'standing',
        'silent': true,
        'renotify': false,
      })).toDart;
    } catch (_) {}
  }

  @override
  Future<void> pocket(Feeling feeling, double intensity) async {
    // There is no vibrator here and there is not going to be one. What the pocket gets instead is
    // the notification carrying the feeling's own name and sound; the rhythm itself is played by
    // Sensation through the page when the app is open. Nothing about the arrival is quieter than
    // it is on the other phone, it just arrives through a different sense.
    if (!_allowed) return;
    try {
      await _registration?.showNotification(feeling.name.toJS, _opts({
        'body': 'held out to you',
        'tag': 'from-them',
        'renotify': true,
        'silent': false,
      })).toDart;
    } catch (_) {}
  }

  @override
  Future<PushSubscription?> subscribe(String vapidPublicKey) async {
    final manager = _registration?.pushManager;
    if (manager == null || !_allowed) return null;
    try {
      var sub = await manager.getSubscription().toDart;
      sub ??= await manager.subscribe(_opts({
        'userVisibleOnly': true,
        'applicationServerKey': vapidPublicKey,
      })).toDart;
      final json = jsonDecode(_stringify(sub.toJSON()).toDart) as Map<String, dynamic>;
      final keys = (json['keys'] as Map?)?.cast<String, dynamic>() ?? const {};
      return PushSubscription(
        endpoint: json['endpoint'] as String,
        p256dh: keys['p256dh'] as String? ?? '',
        auth: keys['auth'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    // This was an empty method, which meant a standing line survived the app being opened: the
    // one thing the surface is for is that it says what is happening while nobody is looking, and
    // it went on saying it afterwards.
    final reg = _registration;
    if (reg == null) return;
    try {
      for (final n in (await reg.getNotifications().toDart).toDart) {
        n.close();
      }
    } catch (_) {}
  }

  @override
  Future<Map<String, Object?>> whatThePhoneCanHold() async {
    bool secure;
    try {
      secure = _isSecureContext?.toDart ?? false;
    } catch (_) {
      secure = false;
    }
    String permission;
    try {
      permission = _permission?.toDart ?? 'unknown';
    } catch (_) {
      permission = 'unknown';
    }
    return {
      'platform': 'a browser',
      // The one that decides all the others. A page served over http at a 100.64/10 address is not
      // a secure context, and Safari then gives it no `navigator.serviceWorker` at all — no worker,
      // no push subscription, no pocket. It is the reason the host serves over TLS.
      'a_secure_origin': secure,
      'service_worker_offered_by_the_browser': _serviceWorker != null,
      'a_worker_is_registered': _registration != null,
      'the_person_has_allowed_it': permission,
      'a_push_manager': _registration?.pushManager != null,
    };
  }

  @override
  Future<List<Map<String, Object?>>> received() async {
    // What the browser is holding, as opposed to what this class asked it to hold. The capture
    // report used to be able to say only the second, which is a record of an intention.
    final reg = _registration;
    if (reg == null) return const [];
    try {
      return [
        for (final n in (await reg.getNotifications().toDart).toDart)
          {
            'title': n.title.toDart,
            'body': n.body.toDart,
            'tag': n.tag.toDart,
            'silent': n.silent,
          },
      ];
    } catch (_) {
      return const [];
    }
  }
}

Ambient ambient() => _WebAmbient();
