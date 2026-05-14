/// Weather condition chip widget.
library;

import 'package:flutter/material.dart';

import '../models/route_model.dart';

class WeatherChip extends StatelessWidget {
  const WeatherChip({super.key, required this.weather, this.compact = false});

  final WeatherInfo weather;
  final bool compact;

  IconData _icon() {
    final c = weather.condition.toLowerCase();
    if (c.contains('clear') || c.contains('sunny')) return Icons.wb_sunny_rounded;
    if (c.contains('cloud')) return Icons.cloud_rounded;
    if (c.contains('rain') || c.contains('drizzle')) return Icons.water_drop_rounded;
    if (c.contains('snow')) return Icons.ac_unit_rounded;
    if (c.contains('thunder') || c.contains('storm')) return Icons.bolt_rounded;
    if (c.contains('fog') || c.contains('mist') || c.contains('haze')) {
      return Icons.blur_on_rounded;
    }
    if (c.contains('wind')) return Icons.air_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Color _color(BuildContext context) {
    final c = weather.condition.toLowerCase();
    if (c.contains('clear') || c.contains('sunny')) {
      return const Color(0xFFF59E0B);
    }
    if (c.contains('rain') || c.contains('drizzle')) {
      return const Color(0xFF3B82F6);
    }
    if (c.contains('thunder') || c.contains('storm')) {
      return const Color(0xFF6D28D9);
    }
    if (c.contains('snow')) return const Color(0xFF60A5FA);
    if (c.contains('fog') || c.contains('mist')) {
      return Theme.of(context).colorScheme.outline;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!weather.isAvailable) {
      final muted = scheme.onSurfaceVariant;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: compact ? 13 : 15, color: muted),
            const SizedBox(width: 4),
            Text(
              compact ? 'No weather' : 'Weather unavailable',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: muted,
              ),
            ),
          ],
        ),
      );
    }

    final color = _color(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(), size: compact ? 13 : 15, color: color),
          const SizedBox(width: 4),
          Text(
            compact
                ? '${weather.tempC.round()}°C'
                : '${weather.condition} · ${weather.tempC.round()}°C',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
