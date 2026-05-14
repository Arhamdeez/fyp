/// Route result card — surfaces and outlines aligned with the rest of Momentum.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/route_model.dart';
import '../route_type_colors.dart';
import '../stores/routes_store.dart';
import 'safety_score_ring.dart';
import 'traffic_indicator.dart';
import 'vehicle_badge.dart';
import 'weather_chip.dart';

class RouteCard extends StatefulWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  final RouteOption route;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard> {
  bool _isSaved = false;

  IconData _typeIcon() => switch (widget.route.type) {
        RouteType.fastest => Icons.flash_on_rounded,
        RouteType.eco => Icons.eco_rounded,
        RouteType.leastTraffic => Icons.traffic_rounded,
        RouteType.recommended => Icons.star_rounded,
      };

  String _smartScoreLabel(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 55) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.route.type.accentColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected
                ? accent.withValues(alpha: 0.65)
                : scheme.outlineVariant.withValues(alpha: 0.85),
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isSelected
                  ? accent.withValues(alpha: 0.22)
                  : scheme.shadow.withValues(alpha: 0.04),
              blurRadius: widget.isSelected ? 14 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        accent.withValues(alpha: 0.45),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(), size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.route.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.route.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafetyScoreRing(
                    score: widget.route.safetyScore,
                    size: 44,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  _StatBox(
                    icon: Icons.schedule_rounded,
                    value: widget.route.etaLabel,
                    label: 'ETA',
                    scheme: scheme,
                    accent: accent,
                  ),
                  const SizedBox(width: 10),
                  _StatBox(
                    icon: Icons.straighten_rounded,
                    value: widget.route.distanceLabel,
                    label: 'Distance',
                    scheme: scheme,
                    accent: accent,
                  ),
                  const SizedBox(width: 10),
                  _StatBox(
                    icon: Icons.local_gas_station_rounded,
                    value: widget.route.fuelEfficiencyLabel,
                    label: 'Fuel',
                    scheme: scheme,
                    accent: accent,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              TrafficIndicator(
                traffic: widget.route.traffic,
                showLabel: true,
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  WeatherChip(
                    weather: widget.route.weather,
                    compact: true,
                  ),
                  VehicleBadge(rec: widget.route.vehicleRec),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.route.smartScore} · ${_smartScoreLabel(widget.route.smartScore)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  _FavButton(
                    isSaved: _isSaved,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      setState(() => _isSaved = !_isSaved);
                      final saved = await RoutesStore.instance
                          .saveCurrentRoute(widget.route);
                      if (saved == null && mounted) {
                        setState(() => _isSaved = false);
                      }
                    },
                    scheme: scheme,
                  ),
                  const Spacer(),
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 11,
                      color: accent.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: accent.withValues(alpha: 0.72),
                  ),
                ],
              ),
            ],
          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.scheme,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final ColorScheme scheme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accent.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  const _FavButton({
    required this.isSaved,
    required this.onTap,
    required this.scheme,
  });

  final bool isSaved;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
            key: ValueKey(isSaved),
            size: 22,
            color: isSaved ? scheme.secondary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
