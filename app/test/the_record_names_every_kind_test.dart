// Every kind of thing the app holds is named somewhere in what the capture writes down.
//
// A completeness pass aggregated the `kinds` blocks across every scene report and found seven of
// the registry's eighteen types. Eleven were never recorded anywhere — photo, reaction,
// message_edit, message_delete, read_marker, state_passive, date_event, milestone, passed_on,
// ping, feeling_authored — several of them visible by eye in the stills, so the picture could not
// be checked against the record for any of them. Four of those live only folded onto somebody
// else's row and one lives on the screen whose whole subject is photographs.
import 'package:desk/capture/bus.dart';
import 'package:desk/modules/registry.dart';
import 'package:desk/spine/types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every event type is somewhere a region says it is showing', () {
    // what the thread names on its own rows
    const thread = {'message', 'photo', 'video', 'voice_note', 'feeling', 'state_declared'};
    // what the thread names as folded onto a row rather than drawn as one
    const folded = {'reaction', 'message_edit', 'message_delete', 'read_marker'};
    // what Pulse names on the two sheets
    const pulse = {'state_declared', 'state_passive', 'feeling', 'feeling_authored', 'ping'};
    // what Us names, from the modules themselves
    final us = {for (final m in kModules) ...m.eventTypes};
    // and what Moments names is every type it can keep, which is the media
    const moments = {'photo', 'video', 'voice_note'};

    final named = {...thread, ...folded, ...pulse, ...us, ...moments};
    final all = {for (final t in kEventTypes) t.id};
    final unnamed = all.difference(named);
    expect(unnamed, isEmpty,
        reason: 'no region says it is showing ${unnamed.join(', ')}, so the record cannot be '
            'checked against the picture for any of them');
    expect(CaptureBus.chatReport, isNull, reason: 'a test left a report handle behind');
  });
}
