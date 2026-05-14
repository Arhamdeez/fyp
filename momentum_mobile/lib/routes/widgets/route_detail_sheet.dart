/// Route detail bottom sheet — compact, matches app Material 3 surfaces.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/route_model.dart';
import '../route_type_colors.dart';
import '../services/maps_launcher.dart';
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

  IconData _typeIcon() => switch (route.type) {
        RouteType.fastest => Icons.flash_on_rounded,
        RouteType.eco => Icons.eco_rounded,
        RouteType.leastTraffic => Icons.traffic_rounded,
        RouteType.recommended => Icons.star_rounded,
      };

  Future<void> _openInMaps(BuildContext context) async {
    final store = RoutesStore.instance;
    final ok = await MapsLauncher.openDirections(
      originLat: store.originLat,
      originLng: store.originLng,
      destLat: store.destLat,
      destLng: store.destLng,
      originLabel: route.originName,
      destLabel: route.destName,
      mapsVariant: route.type,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open Maps. Check that a browser or Maps app is available.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = route.type.accentColor;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.55, 0.72, 0.95],
      builder: (ctx, scrollCtrl) => Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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

              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.20),
                      accent.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.38)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(_typeIcon(), color: accent, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            route.title,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SafetyScoreRing(score: route.safetyScore, size: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${route.originName}  →  ${route.destName}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _SheetStatBadge(
                          scheme: scheme,
                          accent: accent,
                          icon: Icons.schedule_rounded,
                          value: route.etaLabel,
                          label: 'ETA',
                        ),
                        const SizedBox(width: 10),
                        _SheetStatBadge(
                          scheme: scheme,
                          accent: accent,
                          icon: Icons.straighten_rounded,
                          value: route.distanceLabel,
                          label: 'Distance',
                        ),
                        const SizedBox(width: 10),
                        _SheetStatBadge(
                          scheme: scheme,
                          accent: accent,
                          icon: Icons.star_rounded,
                          value: '${route.smartScore}',
                          label: 'Score',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _Section(
                title: 'Weather',
                icon: Icons.cloud_rounded,
                accent: accent,
                child: route.weather.isAvailable
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              WeatherChip(weather: route.weather),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  route.weather.description.isEmpty
                                      ? route.weather.condition
                                      : route.weather.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Wind ${route.weather.windKph.round()} km/h',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (route.weather.isHazardous) ...[
                            const SizedBox(height: 10),
                            _WarningBanner(
                              message: route.weather.warningText,
                              scheme: scheme,
                            ),
                          ],
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WeatherChip(weather: route.weather),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Pass GOOGLE_WEATHER_KEY or WEATHER_API_KEY (--dart-define).',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              _Section(
                title: 'Traffic',
                icon: Icons.traffic_rounded,
                accent: accent,
                child: TrafficIndicator(traffic: route.traffic),
              ),

              _Section(
                title: 'Vehicle',
                icon: Icons.directions_car_rounded,
                accent: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VehicleBadge(rec: route.vehicleRec, large: true),
                    const SizedBox(height: 8),
                    Text(
                      route.vehicleRec.isPlaceholder
                          ? 'Demo suggestion — same for every route for now.'
                          : route.vehicleRec.reason,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (!route.vehicleRec.isPlaceholder) ...[
                      const SizedBox(height: 10),
                      _ConfidenceBar(
                        confidence: route.vehicleRec.confidence,
                        label: route.vehicleRec.confidenceLabel,
                        scheme: scheme,
                        accent: accent,
                      ),
                    ],
                  ],
                ),
              ),

              _Section(
                title: 'Tip',
                icon: Icons.lightbulb_outline_rounded,
                accent: accent,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates_rounded,
                          size: 18, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          route.drivingTip,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _Section(
                title: 'Summary',
                icon: Icons.bar_chart_rounded,
                accent: accent,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _StatTile(
                      icon: Icons.shield_rounded,
                      label: 'Safety',
                      value: '${route.safetyScore}/100',
                      color: accent,
                      scheme: scheme,
                    ),
                    _StatTile(
                      icon: Icons.star_rounded,
                      label: 'Smart score',
                      value: '${route.smartScore}/100',
                      color: accent,
                      scheme: scheme,
                    ),
                    _StatTile(
                      icon: Icons.local_gas_station_rounded,
                      label: 'Fuel',
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

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openInMaps(context),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text(
                          'Open in Maps',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (shareContext) => OutlinedButton.icon(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                try {
                                  await RoutesStore.instance
                                      .shareRoute(shareContext, route);
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Sharing failed. Try again.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.share_rounded),
                              label: const Text('Share'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accent,
                                side: BorderSide(
                                  color:
                                      accent.withValues(alpha: 0.55),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                              side: BorderSide(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.65),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SheetStatBadge extends StatelessWidget {
  const _SheetStatBadge({
    required this.scheme,
    required this.accent,
    required this.icon,
    required this.value,
    required this.label,
  });

  final ColorScheme scheme;
  final Color accent;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                color: scheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
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
        color: scheme.errorContainer.withValues(alpha: 0.55),
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
                  fontSize: 12, color: scheme.onErrorContainer, height: 1.35),
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
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
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
