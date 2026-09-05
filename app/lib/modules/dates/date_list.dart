// The date planner and tracker: a stack of ticket stubs on the desk.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
import '../module.dart';
import 'dates_module.dart';

class DateList extends StatelessWidget {
  const DateList({super.key, required this.ctx});
  final ModuleContext ctx;

  @override
  Widget build(BuildContext context) {
    final dates = projectDates(ctx.events);
    final upcoming = dates.where((d) => d.when != null && d.when!.isAfter(ctx.now) && d.state != 'done' && d.state != 'said').toList()
      ..sort((a, b) => a.when!.compareTo(b.when!));
    final past = dates.where((d) => !upcoming.contains(d)).toList().reversed.toList();
    final ahead = ctx.few(upcoming);
    final rows = <Widget>[
      _Header(label: 'ahead', onAdd: () => _plan(context)),
      if (upcoming.isEmpty)
        Padding(padding: const EdgeInsets.all(12), child: Text("nowhere planned. that's fine.", style: Hands.margin(size: 15))),
      for (var i = 0; i < ahead.length; i++) _Stub(item: ahead[i], ctx: ctx, row: i),
      // where they have been is a long list; on the desk it is one stub under the heading, and
      // the whole of it when the module is opened on its own
      const SizedBox(height: 14),
      const _Header(label: 'been'),
      for (var i = 0; i < (ctx.onTheDesk ? past.take(1) : past.take(40)).length; i++)
        _Stub(item: past[i], ctx: ctx, row: ahead.length + i),
    ];
    if (ctx.onTheDesk) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    }
    return ListView(padding: const EdgeInsets.fromLTRB(4, 4, 4, 90), children: rows);
  }

  Future<void> _plan(BuildContext context) async {
    final title = await _ask(context, 'what, and where');
    if (title == null || title.trim().isEmpty) return;
    final id = 'date_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await ctx.emit('date_event', {'date_id': id, 'action': 'planned', 'title': title.trim()});
  }
}

Future<String?> _ask(BuildContext context, String hint, {String initial = ''}) => askOnPaper(
      context,
      id: hint,
      hint: hint,
      initial: initial,
      hand: Hands.teo(size: 19),
      leaveWord: 'leave it',
    );

class _Header extends StatelessWidget {
  const _Header({required this.label, this.onAdd});
  final String label;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(
          children: [
            Stamped.onDesk(label, size: 11),
            const Spacer(),
            if (onAdd != null)
              GestureDetector(onTap: onAdd, child: Text('add one', style: Hands.margin(size: 14))),
          ],
        ),
      );
}

/// One date as a ticket stub, with what they said about it written underneath.
class _Stub extends StatefulWidget {
  const _Stub({required this.item, required this.ctx, required this.row});
  final DateItem item;
  final ModuleContext ctx;
  final int row;

  @override
  State<_Stub> createState() => _StubState();
}

class _StubState extends State<_Stub> {
  DateItem get item => widget.item;
  ModuleContext get ctx => widget.ctx;

  @override
  Widget build(BuildContext context) {
    final by = item.by ?? ctx.me;
    final width = MediaQuery.sizeOf(context).width - 30;
    // A date is a ticket stub: it was torn off something, and it is the same stub every time.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 18, 5),
      child: Slip(
        id: item.id,
        row: widget.row,
        width: width,
        stock: item.verdict != null ? 'index' : 'receipt',
        onTap: _act,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.title, style: dateStyle(by)),
            const SizedBox(height: 4),
            Row(
              children: [
                Stamped(item.state, size: 9, colour: Pen.margin),
                const SizedBox(width: 8),
                if (item.when != null)
                  Text(DateFormat('d MMM').format(item.when!), style: Hands.margin(size: 13)),
              ],
            ),
            if (item.verdict != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(item.verdict!, style: dateStyle(by)),
              ),
            if (item.note != null)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(item.note!, style: Hands.margin(size: 14))),
          ],
        ),
      ),
    );
  }

  Future<void> _act() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x2E3A2A1C),
      builder: (ctx) => DeskSheet(
        id: 'what.happened.to.it',
        row: 3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in const ['scheduled', 'done', 'said', 'remembered'])
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(ctx, a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(a, style: Hands.teo(size: 18)),
                ),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _apply(choice);
  }

  Future<void> _apply(String choice) async {
    final payload = <String, dynamic>{'date_id': item.id, 'action': choice, 'title': item.title};
    if (choice == 'scheduled') {
      payload['when'] = DateTime.now().add(const Duration(days: 7)).toIso8601String();
    }
    if (choice == 'said') {
      // What it was, in your own words. There is nothing to pick from and nothing to score: the
      // question is the one a person asks, and whatever you write is what the date carries.
      final said = await _ask(context, 'what was it');
      if (said == null || said.trim().isEmpty) return;
      payload['verdict'] = said.trim();
    }
    await ctx.emit('date_event', payload);
  }
}
