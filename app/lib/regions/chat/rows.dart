// One renderer per event type (unstyled). regions/chat/renderers gets the material versions in
// step 06; the mapping from type to renderer stays here.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../feelings/registry.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import '../../voice/strings.dart';
import 'blob_widgets.dart';
import 'viewer_page.dart';

String timeLabel(int ts) => DateFormat('EEE d MMM · HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts).toLocal());

class ThreadRow extends StatelessWidget {
  const ThreadRow({super.key, required this.item, required this.registry, required this.onLongPress, this.highlight = false});
  final ThreadItem item;
  final FeelingRegistry registry;
  final VoidCallback onLongPress;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final mine = item.author == scope.me;
    final theme = Theme.of(context);
    final body = _body(context);
    final isMargin = const {'state_declared', 'state_passive', 'ritual_kept', 'milestone', 'date_event', 'todo_event', 'ping', 'feeling_authored'}.contains(item.type);
    if (isMargin) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: DefaultTextStyle(style: theme.textTheme.bodySmall!.copyWith(color: theme.hintColor), child: body)),
            Text(timeLabel(item.ts), style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor)),
          ],
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: highlight
                ? theme.colorScheme.tertiaryContainer
                : (mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.replyTo != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(border: Border(left: BorderSide(color: theme.hintColor, width: 2))),
                  child: Text(_summary(item.replyTo!.type, item.replyTo!.payload), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
              body,
              if (item.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final r in item.reactions)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          label: Text('${registry.byId(r.feelingId)?.name ?? r.feelingId} · ${r.by.name}', style: const TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    timeLabel(item.ts),
                    if (item.writtenEarlier) S.writtenEarlier,
                    if (item.edited) S.edited,
                    if (mine)
                      switch (item.delivery) {
                        Delivery.waiting => S.waitingToSend,
                        Delivery.sent => S.sent,
                        Delivery.read => S.read,
                      },
                  ].join(' · '),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final p = item.event.payload;
    if (item.deleted) return Text(S.tookBack, style: const TextStyle(fontStyle: FontStyle.italic));
    switch (item.type) {
      case 'message':
        return Text(item.text ?? '');
      case 'photo':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => ViewerPage.open(context, item),
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: BlobImage(hash: p['blob'] as String, width: 240, height: 240 * (p['h'] as num) / (p['w'] as num))),
            ),
            if (item.text != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(item.text!)),
          ],
        );
      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => ViewerPage.open(context, item),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: BlobImage(hash: p['poster_blob'] as String, width: 240, height: 240 * (p['h'] as num) / (p['w'] as num))),
                  const Icon(Icons.play_circle_outline, size: 48),
                ],
              ),
            ),
            Text('${S.video} · ${((p['duration_ms'] as num) / 1000).round()}s', style: const TextStyle(fontSize: 12)),
            if (item.text != null) Text(item.text!),
          ],
        );
      case 'voice_note':
        return VoiceNotePlayer(
          hash: p['blob'] as String,
          durationMs: (p['duration_ms'] as num).toInt(),
          waveform: (p['waveform'] as List).map((x) => (x as num).toDouble()).toList(),
        );
      case 'feeling':
        final f = registry.byId(p['feeling_id'] as String);
        return Text('◆ ${f?.name ?? p['feeling_id']}  ${((p['intensity'] as num) * 100).round()}%');
      default:
        return Text(_summary(item.type, p));
    }
  }

  static String _summary(String type, Map<String, dynamic> p) {
    switch (type) {
      case 'message':
        return p['text'] as String? ?? '';
      case 'photo':
        return '${S.photo}${p['caption'] != null ? ' · ${p['caption']}' : ''}';
      case 'video':
        return S.video;
      case 'voice_note':
        return S.voiceNote;
      case 'feeling':
        return '◆ ${p['feeling_id']}';
      case 'state_declared':
        return '${p['signal']}: ${p['value']}';
      case 'state_passive':
        return '${p['signal']} ${p['value']}';
      case 'date_event':
        return 'date · ${p['action']} · ${p['title']}${p['rating'] != null ? ' · ${p['rating']}/5' : ''}${p['note'] != null ? ' · ${p['note']}' : ''}';
      case 'todo_event':
        return 'to do · ${p['action']} · ${p['text']}${p['assignee'] != null ? ' → ${p['assignee']}' : ''}';
      case 'milestone':
        return 'milestone · ${p['title']} · ${p['date']}';
      case 'ritual_kept':
        return 'kept · ${p['title']}';
      case 'ping':
        return 'ping · ${p['text']} · ${p['fires_at']}';
      case 'feeling_authored':
        return 'new feeling · ${p['name']}';
      default:
        return type;
    }
  }
}

String summaryOf(String type, Map<String, dynamic> payload) => ThreadRow._summary(type, payload);
