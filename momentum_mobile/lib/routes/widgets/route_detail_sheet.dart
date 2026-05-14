/// Full route detail bottom sheet with all stats, tips, and CTAs.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/route_model.dart';
import '../stores/routes_store.dart';
import 'safety_score_ring.dart';
import 'traffic_indicator.dart';
import 'vehicle_badge.dart';
import 'weather_chip.dart';

void showRouteDetailSheet(BuildContext context, RouteOption route) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RouteDetailSheet(route: route),
  );
}

class RouteDetailSheet extends StatelessWidget {
  const RouteDetailSheet({super.key, required this.route});

  final RouteOption route;

  Color _typeColor() => switch (route.type) {
        RouteType.fastest => const Color(0xFF2563EB),
        RouteType.eco => const Color(0xFF16A34A),
        RouteType.leastTraffic => const Color(0xFFF59E0B),
        RouteType.recommended => const Color(0xFF0D9488),
      };

  IconData _typeIcon() => switch (route.type) {
        RouteType.fastest => Icons.flash_on_rounded,
        RouteType.eco => Icons.eco_rounded,
        RouteType.leastTraffic => Icons.traffic_rounded,
        RouteType.recommended => Icons.auto_awesome_rounded,
      };

  Future<void> _openInMaps(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${route.originName.replaceAll(' ', '+')}'
      '&destination=${route.destName.replaceAll(' ', '+')}',
    );
    // We just launch the URL via the platform — no url_launcher needed for this demo path
    // We use a simple snackbar to inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: $uri'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _typeColor();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.55, 0.72, 0.95],
      builder: (ctx, scrollCtrl) => Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ────────────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // ── Gradient header ────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_typeIcon(), color: Colors.white, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            route.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        SafetyScoreRing(score: route.safetyScore, size: 52),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${route.originName}  →  ${route.destName}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _WhiteStatBadge(
                          icon: Icons.schedule_rounded,
                          value: route.etaLabel,
                          label: 'ETA',
                        ),
                        const SizedBox(width: 10),
                        _WhiteStatBadge(
                          icon: Icons.straighten_rounded,
                          value: route.distanceLabel,
                          label: 'Distance',
                        ),
                        const SizedBox(width: 10),
                        _WhiteStatBadge(
                          icon: Icons.star_rounded,
                          value: '${route.smartScore}',
                          label: 'Score',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Weather section ────────────────────────────────────────
              _Section(
                title: 'Weather Conditions',
                icon: Icons.cloud_rounded,
                child: Column(
                  children: [
                    Row(
                      children: [
                        WeatherChip(weather: route.weather),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                route.weather.description.isEmpty
                                    ? route.weather.condition
                                    : route.weather.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Wind: ${route.weather.windKph.round()} km/h',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (route.weather.isHazardous) ...[
                      const SizedBox(height: 10),
                      _WarningBanner(
                        message: route.weather.warningText,
                        scheme: scheme,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Traffic section ────────────────────────────────────────
              _Section(
                title: 'Traffic Status',
                icon: Icons.traffic_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TrafficIndicator(traffic: route.traffic),
                    const SizedBox(height: 8),
                    Text(
                      route.traffic.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (route.traffic.delayMinutes > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Estimated delay: +${route.traffic.delayMinutes} minutes',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Vehicle recommendation section ─────────────────────────
              _Section(
                title: 'Vehicle Recommendation',
                icon: Icons.directions_car_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VehicleBadge(rec: route.vehicleRec, large: true),
                    const SizedBox(height: 10),
                    Text(
                      route.vehicleRec.reason,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    _ConfidenceBar(
                      confidence: route.vehicleRec.confidence,
                      label: route.vehicleRec.confidenceLabel,
                      scheme: scheme,
                      accent: accent,
                    ),
                  ],
                ),
              ),

              // ── Smart tip section ──────────────────────────────────────
              _Section(
                title: 'Smart Travel Tip',
                icon: Icons.lightbulb_rounded,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.tips_and_updates_rounded,
                          size: 20, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          route.drivingTip,
                          style: const TextStyle(fontSize: 13, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Route statistics grid ──────────────────────────────────
              _Section(
                title: 'Route Statistics',
                icon: Icons.bar_chart_rounded,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatTile(
                      icon: Icons.shield_rounded,
                      label: 'Safety Score',
                      value: '${route.safetyScore}/100',
                      color: accent,
                      scheme: scheme,
                    ),
                    _StatTile(
                      icon: Icons.star_rounded,
                      label: 'Smart Score',
                      value: '${route.smartScore}/100',
                      color: accent,
                      scheme: scheme,
                    ),
                    _StatTile(
                      icon: Icons.local_gas_station_rounded,
                      label: 'Fuel Efficiency',
                      value: route.fuelEfficiencyLabel,
                      color: accent,
                      scheme: scheme,
                    ),
                    _StatTile(
                      icon: Icons.percent_rounded,
                      label: 'Congestion',
                      value: '${route.traffic.congestionPct}%',
                      color: accent,
                      scheme: scheme,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Action buttons ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    // Open in Maps
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openInMaps(context),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text(
                          'Open in Maps',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Share
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await RoutesStore.instance.shareRoute(route);
                            },
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(
                                  color: accent.withValues(alpha: 0.5)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Save
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await RoutesStore.instance
                                  .saveCurrentRoute(route);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Route saved to favourites'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.bookmark_add_rounded),
                            label: const Text('Save'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF59E0B),
                              side: const BorderSide(
                                  color: Color(0xFFF59E0B), width: 0.8),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _WhiteStatBadge extends StatelessWidget {
  const _WhiteStatBadge({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message, required this.scheme});

  final String message;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 12, color: scheme.onErrorContainer, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({
    required this.confidence,
    required this.label,
    required this.scheme,
    required this.accent,
  });

  final double confidence;
  final String label;
  final ColorScheme scheme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            Text(
              '${(confidence * 100).round()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: confidence),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: accent.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 32 - 10) / 2,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
