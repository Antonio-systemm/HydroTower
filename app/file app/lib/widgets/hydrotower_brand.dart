import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../theme.dart';

class HydroTowerBrand extends StatelessWidget {
  const HydroTowerBrand({super.key, this.sezione, this.iconSize = 30});

  final String? sezione;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final String titolo = sezione == null || sezione!.trim().isEmpty
        ? 'HydroTower'
        : 'HydroTower · $sezione';

    return Semantics(
      header: true,
      label: titolo,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(TablerIcons.plant_2, size: iconSize, color: HydroColors.accent),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              titolo,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HydroColors.accent,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
