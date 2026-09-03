// Us: the couple's shared life, one tab per module, all of them writing into the same spine.
// The tabs come from modules/registry.dart, so a fifth module appears here without this file
// changing.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../modules/module.dart';
import '../../modules/registry.dart';
import '../../scope.dart';

class UsRegion extends StatefulWidget {
  const UsRegion({super.key});

  @override
  State<UsRegion> createState() => _UsRegionState();
}

class _UsRegionState extends State<UsRegion> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final events = scope.spine.all;
    final ctx = ModuleContext(
      events: events,
      me: scope.me,
      partner: scope.partner,
      now: scope.clock.now().toLocal(),
      emit: scope.emit,
    );
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (var i = 0; i < kModules.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: i == _tab ? const Color(0xFFF6F1E6) : const Color(0x33F6F1E6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stamped(kModules[i].label, size: i == _tab ? 11 : 10,
                            colour: i == _tab ? Pen.stamp : Pen.margin),
                        Text(kModules[i].glance(events), style: Hands.margin(size: 11)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: kModules[_tab].build(context, ctx)),
      ],
    );
  }
}
