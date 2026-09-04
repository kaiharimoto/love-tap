// The date planner and tracker: a stack of ticket stubs on the desk.
import 'package:flutter/material.dart';

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
    final upcoming = dates.where((d) => d.when != null && d.when!.isAfter(ctx.now) && d.state != 'done' && d.state != 'rated').toList()
      ..sort((a, b) => a.when!.compareTo(b.when!));
    final past = dates.where((d) => !upcoming.contains(d)).toList().reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 90),
      children: [
        _Header(label: 'ahead', onAdd: () => _plan(context)),
        if (upcoming.isEmpty)
          Padding(padding: const EdgeInsets.all(12), child: Text("nowhere planned. that's fine.", style: Hands.margin(size: 15))),
        for (var i = 0; i < upcoming.length; i++) _Stub(item: upcoming[i], ctx: ctx, row: i),
        const SizedBox(height: 14),
        const _Header(label: 'been'),
        for (var i = 0; i < past.take(40).length; i++) _Stub(item: past[i], ctx: ctx, row: upcoming.length + i),
      ],
    );
  }

  Future<void> _plan(BuildContext context) async {
    final title = await _ask(context, 'what, and where');
    if (title == null || title.trim().isEmpty) return;
    final id = 'date_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    await ctx.emit('date_event', {'date_id': id, 'action': 'planned', 'title': title.trim()});
  }
}

Future<String?> _ask(BuildContext context, String hint, {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFFF1ECDF),
      content: TextField(
        controller: c,
        autofocus: true,
        style: Hands.teo(size: 19),
        decoration: InputDecoration(hintText: hint, hintStyle: Hands.margin(size: 16)),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('leave it', style: Hands.margin(size: 15))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('keep', style: Hands.margin(size: 15))),
      ],
    ),
  );
}

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

/// One date as a ticket stub, with its rating in pencil stars.
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
        stock: item.rating != null ? 'index' : 'receipt',
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
                  Text('${item.when!.day}/${item.when!.month}', style: Hands.margin(size: 13)),
                const Spacer(),
                if (item.rating != null) Stars(rating: item.rating!),
              ],
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
      backgroundColor: const Color(0xFFF1ECDF),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in const ['scheduled', 'done', 'rated', 'remembered'])
              ListTile(title: Text(a, style: Hands.teo(size: 18)), onTap: () => Navigator.pop(ctx, a)),
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
    if (choice == 'rated') {
      final note = await _ask(context, 'a line about it');
      payload['rating'] = 4;
      if (note != null && note.trim().isNotEmpty) payload['note'] = note.trim();
    }
    await ctx.emit('date_event', payload);
  }
}
