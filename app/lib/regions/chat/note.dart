// A note in the thread: the material rendering of one spine event.
//
// Every row is a piece of paper torn from a stock, written in its author's hand, lying on the desk
// with the contact shadow that came out of its own render. Replies are pinned over a torn strip of
// the note they answer; reactions are objects stuck to the paper; delivery and read are marks in
// the margin rather than rows.
import 'package:flutter/material.dart';

import '../../feelings/builtins.dart';
import '../../feelings/registry.dart';
import '../../material/assignment.dart';
import '../../material/hands.dart';
import '../../material/library.dart';
import '../../material/objects.dart';
import '../../material/paper.dart';
import '../../material/palette.dart';
import '../../scope.dart';
import '../../spine/projections/thread.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import 'blob_widgets.dart';
import 'rows.dart' show timeLabel;
import 'viewer_page.dart';

/// The width a note takes on the desk, as a fraction of the region's width.
const double _noteWidthFraction = 0.76;

class Note extends StatelessWidget {
  const Note({
    super.key,
    required this.item,
    required this.registry,
    required this.onLongPress,
    this.highlight = false,
  });

  final ThreadItem item;
  final FeelingRegistry registry;
  final VoidCallback onLongPress;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final mine = item.author == scope.me;
    final e = item.event;

    // margin events: a pencil line beside the thread, not a piece of paper
    if (_isMarginal(item.type)) return _MarginLine(item: item, registry: registry);

    final width = MediaQuery.sizeOf(context).width * _noteWidthFraction;
    final stock = lib == null ? '' : stockVariantFor(e, lib);
    final tear = lib == null ? null : tearFor(e, lib);
    final lift = liftFor(e);
    final tilt = tiltFor(e) + (mine ? -0.004 : 0.004);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(mine ? 40 : 14, 7, mine ? 14 : 40, 7),
          child: PaperPiece(
            stockId: stock,
            tearId: tear,
            liftMm: lift,
            tilt: tilt,
            width: width,
            stockAlignment: _patchOf(e),
            stockScale: 1.15,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            safe: lib == null || tear == null ? const [0.06, 0.07, 0.06, 0.07] : lib.safeOf(tear),
            overlays: [
              if (item.reactions.isNotEmpty)
                Positioned(
                  right: 14,
                  bottom: -6,
                  child: Row(
                    children: [
                      for (final r in item.reactions.take(3))
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: FeelingObject(
                            feeling: registry.byId(r.feelingId) ?? kBuiltInFeelings.first,
                            size: 46,
                            intensity: 0.6,
                            tilt: (r.eventId.hashCode % 20 - 10) / 90,
                          ),
                        ),
                    ],
                  ),
                ),
              if (highlight)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(decoration: const BoxDecoration(color: Accent.highlighterYellow)),
                  ),
                ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.replyTo != null) _ReplyStrip(target: item.replyTo!, registry: registry),
                _body(context, scope),
                const SizedBox(height: 6),
                _Margin(item: item, mine: mine),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _isMarginal(String type) => const {
        'state_declared', 'state_passive', 'ritual_kept', 'milestone', 'date_event', 'todo_event',
        'ping', 'feeling_authored',
      }.contains(type);

  /// Which square of the stock this note is torn from, so two notes never show the same paper.
  static Alignment _patchOf(Event e) {
    final h = hashOf(e.id);
    return Alignment(((h % 100) / 50.0) - 1.0, (((h >> 7) % 100) / 50.0) - 1.0);
  }

  Widget _body(BuildContext context, AppScope scope) {
    final e = item.event;
    final p = e.payload;
    if (item.deleted) {
      return Written(S.tookBack, by: item.author, size: 17, colour: Pen.margin);
    }
    switch (item.type) {
      case 'message':
        return Written(item.text ?? '', by: item.author, size: 20);
      case 'photo':
        return _Print(
          item: item,
          hash: p['blob'] as String,
          aspect: (p['w'] as num) / (p['h'] as num),
          caption: item.text,
        );
      case 'video':
        return _Print(
          item: item,
          hash: p['poster_blob'] as String,
          aspect: (p['w'] as num) / (p['h'] as num),
          caption: item.text,
          durationMs: (p['duration_ms'] as num).toInt(),
        );
      case 'voice_note':
        return VoiceNotePlayer(
          hash: p['blob'] as String,
          durationMs: (p['duration_ms'] as num).toInt(),
          waveform: (p['waveform'] as List).map((x) => (x as num).toDouble()).toList(),
        );
      case 'feeling':
        final f = registry.byId(p['feeling_id'] as String);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (f != null) FeelingObject(feeling: f, size: 96, intensity: (p['intensity'] as num).toDouble()),
            const SizedBox(width: 10),
            Flexible(child: Written(f?.name ?? '', by: item.author, size: 19)),
          ],
        );
      default:
        return Written(item.text ?? item.type, by: item.author, size: 18);
    }
  }
}

/// A photograph or a video still, taped to the note at two corners.
class _Print extends StatelessWidget {
  const _Print({required this.item, required this.hash, required this.aspect, this.caption, this.durationMs});
  final ThreadItem item;
  final String hash;
  final double aspect;
  final String? caption;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final lib = MaterialLibrary.loaded ? MaterialLibrary.instance : null;
    final bits = lib?.bits ?? const [];
    final tape = bits.isEmpty ? null : bits[hashOf(item.id) % bits.length].id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => ViewerPage.open(context, item),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(aspectRatio: aspect, child: BlobImage(hash: hash, fit: BoxFit.cover)),
              if (tape != null)
                Positioned(
                  left: -10,
                  top: -8,
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Image.asset(bitAsset(tape), width: 60, errorBuilder: PaperPiece.none),
                  ),
                ),
              if (durationMs != null)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: Stamped('${(durationMs! / 1000).round()}s', size: 11, colour: Pen.margin),
                ),
            ],
          ),
        ),
        if (caption != null && caption!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Written(caption!, by: item.author, size: 17)),
      ],
    );
  }
}

/// The note being answered, as a torn strip pinned above the reply.
class _ReplyStrip extends StatelessWidget {
  const _ReplyStrip({required this.target, required this.registry});
  final Event target;
  final FeelingRegistry registry;

  @override
  Widget build(BuildContext context) {
    final text = switch (target.type) {
      'message' => target.payload['text'] as String? ?? '',
      'photo' => S.photo,
      'video' => S.video,
      'voice_note' => S.voiceNote,
      'feeling' => registry.byId(target.payload['feeling_id'] as String)?.name ?? '',
      _ => target.type,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: Pen.margin, width: 1.2))),
      child: Written(text, by: target.author, size: 15, colour: Pen.margin, maxLines: 2),
    );
  }
}

/// The pencil line under a note: when it was written, whether it has been read.
class _Margin extends StatelessWidget {
  const _Margin({required this.item, required this.mine});
  final ThreadItem item;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      timeLabel(item.ts),
      if (item.writtenEarlier) S.writtenEarlier,
      if (item.edited) S.edited,
      if (mine)
        switch (item.delivery) {
          Delivery.waiting => S.waitingToSend,
          Delivery.sent => S.sent,
          Delivery.read => S.read,
        },
    ];
    return Opacity(opacity: 0.75, child: Text(bits.join(' · '), style: Hands.margin(size: 12)));
  }
}

/// Module and state events: a mark in the margin of the desk rather than a note of their own.
class _MarginLine extends StatelessWidget {
  const _MarginLine({required this.item, required this.registry});
  final ThreadItem item;
  final FeelingRegistry registry;

  @override
  Widget build(BuildContext context) {
    final p = item.event.payload;
    final text = switch (item.type) {
      'state_declared' => '${p['signal']} · ${p['value']}',
      'state_passive' => '${p['signal']} ${p['value']}',
      'date_event' => '${p['action']} · ${p['title']}${p['rating'] != null ? ' · ${p['rating']}/5' : ''}',
      'todo_event' => '${p['action']} · ${p['text']}',
      'milestone' => '${p['title']} · ${p['date']}',
      'ritual_kept' => 'kept · ${p['title']}',
      'ping' => '${p['text']} · ${p['fires_at']}',
      'feeling_authored' => 'a new one · ${p['name']}',
      _ => item.type,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 6),
      child: Row(
        children: [
          Container(width: 14, height: 1, color: Pen.margin.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Hands.margin(size: 13))),
          Text(timeLabel(item.ts), style: Hands.margin(size: 11.5)),
        ],
      ),
    );
  }
}
