/// Premium route result card with all metrics displayed.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/route_model.dart';
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
    required this.onFavorite,
  });

  final RouteOption route;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  State<RouteCard> createState() => _RouteCardState();
}

class _RouteCardState extends State<RouteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _enterAnim;
  bool _isSaved = false;

  Color _typeColor() => switch (widget.route.type) {
        RouteType.fastest => const Color(0xFF2563EB),
        RouteType.eco => const Color(0xFF16A34A),
        RouteType.leastTraffic => const Color(0xFFF59E0B),
        RouteType.recommended => const Color(0xFF0D9488),
      };

  IconData _typeIcon() => switch (widget.route.type) {
        RouteType.fastest => Icons.flash_on_rounded,
        RouteType.eco => Icons.eco_rounded,
        RouteType.leastTraffic => Icons.traffic_rounded,
        RouteType.recommended => Icons.auto_awesome_rounded,
      };

  String _smartScoreLabel(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 55) return 'Fair';
    return 'Poor';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _enterAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accentColor = _typeColor();

    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.0).animate(_enterAnim),
      child: FadeTransition(
        opacity: _enterAnim,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isSelected
                    ? accentColor.withValues(alpha: 0.6)
                    : scheme.outlineVariant.withValues(alpha: 0.4),
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? accentColor.withValues(alpha: 0.18)
                      : scheme.shadow.withValues(alpha: 0.08),
                  blurRadius: widget.isSelected ? 20 : 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left accent bar
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            accentColor.withValues(alpha: 0.5),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Card content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Header row ──────────────────────────────
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _typeIcon(),
                                    size: 16,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                // Safety ring
                                SafetyScoreRing(
                                  score: widget.route.safetyScore,
                                  size: 48,
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // ── ETA + Distance ───────────────────────────
                            Row(
                              children: [
                                _StatBox(
                                  icon: Icons.schedule_rounded,
                                  value: widget.route.etaLabel,
                                  label: 'ETA',
                                  color: accentColor,
                                  scheme: scheme,
                                ),
                                const SizedBox(width: 10),
                                _StatBox(
                                  icon: Icons.straighten_rounded,
                                  value: widget.route.distanceLabel,
                                  label: 'Distance',
                                  color: accentColor,
                                  scheme: scheme,
                                ),
                                const SizedBox(width: 10),
                                _StatBox(
                                  icon: Icons.local_gas_station_rounded,
                                  value: widget.route.fuelEfficiencyLabel,
                                  label: 'Fuel',
                                  color: accentColor,
                                  scheme: scheme,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // ── Traffic indicator ────────────────────────
                            TrafficIndicator(
                              traffic: widget.route.traffic,
                              showLabel: true,
                            ),

                            const SizedBox(height: 12),

                            // ── Bottom chips row ─────────────────────────
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                WeatherChip(
                                  weather: widget.route.weather,
                                  compact: true,
                                ),
                                VehicleBadge(rec: widget.route.vehicleRec),
                                // Smart score chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded,
                                          size: 12, color: accentColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.route.smartScore} · ${_smartScoreLabel(widget.route.smartScore)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: accentColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // ── Action row ───────────────────────────────
                            Row(
                              children: [
                                // Favorite button
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
                                ),
                                const Spacer(),
                                // "View details" hint
                                Text(
                                  'Tap for details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
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
    required this.color,
    required this.scheme,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
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
  const _FavButton({required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

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
            color: isSaved
                ? const Color(0xFFF59E0B)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
