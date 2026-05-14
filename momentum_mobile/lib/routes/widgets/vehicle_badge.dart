/// Vehicle recommendation badge widget.
library;

import 'package:flutter/material.dart';

import '../models/route_model.dart';

class VehicleBadge extends StatelessWidget {
  const VehicleBadge({
    super.key,
    required this.rec,
    this.large = false,
  });

  final VehicleRecommendation rec;
  final bool large;

  IconData _icon() => switch (rec.vehicle) {
        VehicleType.bicycle => Icons.directions_bike_rounded,
        VehicleType.motorcycle => Icons.two_wheeler_rounded,
        VehicleType.car => Icons.directions_car_rounded,
        VehicleType.walk => Icons.directions_walk_rounded,
      };

  Color _color() => switch (rec.vehicle) {
        VehicleType.bicycle => const Color(0xFF16A34A),
        VehicleType.motorcycle => const Color(0xFF7C3AED),
        VehicleType.car => const Color(0xFF0D9488),
        VehicleType.walk => const Color(0xFF2563EB),
      };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final iconSize = large ? 28.0 : 18.0;
    final fontSize = large ? 13.0 : 11.0;
    final pad = large
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);

    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(large ? 16 : 20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: iconSize, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rec.vehicleLabel,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
