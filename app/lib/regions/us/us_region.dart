// Us: the couple's shared life, one tab per module, all of them writing into the same spine.
// The tabs come from modules/registry.dart, so a fifth module appears here without this file
// changing.
import 'package:flutter/material.dart';

import '../../material/hands.dart';
import '../../material/palette.dart';
import '../../material/slip.dart';
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
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (var i = 0; i < kModules.length; i++)
                Padding(
                  // the one being read sits flat; the others are still half under it
                  padding: EdgeInsets.fromLTRB(4, i == _tab ? 4 : 10, 4, i == _tab ? 8 : 2),
                  child: Opacity(
                    opacity: i == _tab ? 1.0 : 0.78,
                    child: Slip(
                      id: 'us.${kModules[i].id}',
                      row: i,
                      stock: 'index',
                      torn: false,
                      width: 152,
                      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
                      onTap: () => setState(() => _tab = i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stamped(kModules[i].label, size: i == _tab ? 11 : 10,
                              colour: i == _tab ? Pen.stamp : Pen.margin),
                          Text(kModules[i].glance(events), style: Hands.margin(size: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
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
