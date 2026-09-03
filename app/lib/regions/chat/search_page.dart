// Full-text and media search across every event type in the spine.
import 'package:flutter/material.dart';

import '../../scope.dart';
import '../../spine/spine.dart';
import '../../voice/strings.dart';
import 'rows.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  /// Returns the chosen event id, or null.
  static Future<String?> open(BuildContext context) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const SearchPage()));

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctl = TextEditingController();
  List<SearchHit> _hits = const [];
  String? _typeFilter;
  Person? _author;

  static const _facets = {
    'all': null,
    'notes': 'message',
    'photos': 'photo',
    'videos': 'video',
    'voice': 'voice_note',
    'feelings': 'feeling',
    'dates': 'date_event',
    'to-dos': 'todo_event',
    'state': 'state_declared',
  };

  void _run() {
    final spine = AppScope.of(context).spine;
    setState(() {
      _hits = spine.search(_ctl.text, types: _typeFilter == null ? null : {_typeFilter!}, author: _author);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: S.searchHint, border: InputBorder.none),
          onChanged: (_) => _run(),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final f in _facets.entries)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: ChoiceChip(
                      label: Text(f.key),
                      selected: _typeFilter == f.value,
                      onSelected: (_) {
                        _typeFilter = f.value;
                        _run();
                      },
                    ),
                  ),
                for (final p in Person.values)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilterChip(
                      label: Text(p.name),
                      selected: _author == p,
                      onSelected: (v) {
                        _author = v ? p : null;
                        _run();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _hits.isEmpty && _ctl.text.isNotEmpty
                ? const Center(child: Text(S.searchNothing))
                : ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (context, i) {
                      final e = _hits[i].event;
                      return ListTile(
                        dense: true,
                        leading: Text(e.author.name),
                        title: Text(summaryOf(e.type, e.payload), maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${e.type} · ${timeLabel(e.ts)}'),
                        onTap: () => Navigator.of(context).pop(e.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
