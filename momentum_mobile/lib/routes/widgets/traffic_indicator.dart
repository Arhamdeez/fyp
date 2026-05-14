/// Traffic level indicator bar widget.
library;

import 'package:flutter/material.dart';

import '../models/route_model.dart';

class TrafficIndicator extends StatelessWidget {
  const TrafficIndicator({
    super.key,
    required this.traffic,
    this.showLabel = true,
  });

  final TrafficInfo traffic;
  final bool showLabel;

  Color _color(ColorScheme scheme) => switch (traffic.level) {
        TrafficLevel.low => scheme.primary,
        TrafficLevel.moderate => scheme.secondary,
        TrafficLevel.heavy => scheme.error,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _color(scheme);
    final pct = traffic.congestionPct / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                traffic.levelLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (traffic.delayMinutes > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '· ${traffic.delayLabel}',
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        if (showLabel) const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}
