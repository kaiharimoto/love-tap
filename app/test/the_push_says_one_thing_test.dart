// The push worker's words are the registry's types, and nothing else.
//
// "A second per-type table outside the registry, in a file app/test/module_costs_test.dart cannot
// see because it enumerates only Directory('lib') files ending in .dart — and it has already
// drifted: it names four modules' event types outside those modules' directories, gives a word to
// ritual_kept which the registry marks Notify.none, and has no word for passed_on, the fifth
// module's own Notify.quiet type."
//
// app/web/push/sw.js is not Dart and cannot import the registry: it is the service worker, and it
// runs when the app is not. So the list is held to the registry from here instead — a kind that
// may announce itself has a word, a kind that may not has none, and there is no word for anything
// the registry does not know about.
import 'dart:io';

import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('web/push/sw.js').readAsStringSync();

  test('the worker keeps no table of its own', () {
    // A per-type table in a file that cannot import the registry is a second registry, and it had
    // already drifted. The words are the registry's; the app writes them into its own store at
    // startup and the worker reads them there.
    expect(src, isNot(contains('const WORDS')),
        reason: 'the worker has a per-type table again');
    expect(src, contains('push.words'), reason: 'the worker does not read the words anywhere');
    // The one type id it may name is the kind a payload defaults to when it cannot be read; an
    // arrival with nothing legible in it is still an arrival. Everything else it knows, it looks
    // up. ('message' is also the name of a DOM event, which is why this counts quoted ids.)
    final named = {
      for (final t in kEventTypes)
        if (src.contains("'${t.id}'")) t.id,
    };
    expect(named, {'message'}, reason: 'the worker names the event types $named');
  });

  test('every kind that may announce itself has a line, and no other kind has one', () {
    for (final t in kEventTypes) {
      if (t.notify == Notify.none) {
        expect(t.pushed, isNull,
            reason: '${t.id} never announces itself and has a line for when it does');
      } else {
        expect(t.pushed, isNotNull,
            reason: '${t.id} may announce itself and would arrive with no words for it');
      }
    }
  });

  test('the worker asks the phone what it was allowed to do', () {
    // The treatment and the quiet hours are declared per type and settable per type, and for five
    // cycles nothing read either. The worker is where the question is actually asked.
    expect(src, contains('notify.prefs'),
        reason: 'the worker does not read what the person allowed');
    expect(src, contains('treatmentFor'), reason: 'the worker has no treatment to apply');
    expect(src, contains("if (how === 'off') return;"),
        reason: 'a kind turned off still shows a notification');
  });

  test('a push still carries nothing but the kind and who sent it', () {
    // the rule that must survive every change to this file
    final push = src.substring(src.indexOf("addEventListener('push'"));
    // `event.data.json()` is how the payload is read at all; what is read *out* of it is the
    // question, so the reader itself is not one of the fields.
    final read = RegExp(r'data\.(\w+)').allMatches(push).map((m) => m.group(1)!).toSet()
      ..remove('json');
    expect(read, {'kind', 'from'},
        reason: 'the worker reads $read out of a push payload; it may read the kind and who sent '
            'it and nothing else');
  });
}
