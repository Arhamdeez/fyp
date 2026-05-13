import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../dashboard/vehicle_insights.dart';
import '../../live/location_store.dart';
import '../../live/obd_live_store.dart';
import '../../telemetry/ride_db.dart';
import '../../telemetry/ride_record.dart';
import '../last_ride_report_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.api,
    this.onNavigateToTab,
  });

  final MomentumApi api;

  /// Main shell passes this so “View tips” can jump to the recommendations tab (index `5`).
  final void Function(int index)? onNavigateToTab;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _loading = true;
  bool _usingDemo = false;
  List<dynamic> _vehicles = const [];

  RideRecord? _lastRide;
  FleetRollup _fleetRollup = rollupInsights(const []);
  List<VehicleAttention> _attention = const [];

  @override
  void initState() {
    super.initState();
    LocationStore.instance.refresh();
    _load();
  }

  String _vehicleIdFrom(Map<String, dynamic> v) =>
      (v['_id'] ?? v['vehicle_id']).toString();

  String _vehicleName(Map<String, dynamic> v) =>
      v['vehicle_model']?.toString().trim().isNotEmpty == true
          ? v['vehicle_model'].toString()
          : 'Vehicle';

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _usingDemo = false;
    });

    RideRecord? ride;
    try {
      ride = await RideDb.instance.latestRide();
    } catch (_) {
      ride = null;
    }

    List<dynamic> v = const [];
    var usingDemo = false;
    try {
      v = await widget.api.vehicles();
      if (v.isEmpty) {
        v = MomentumApi.dummyVehicles();
        usingDemo = true;
      }
    } catch (_) {
      v = MomentumApi.dummyVehicles();
      usingDemo = true;
    }

    final insights = <VehicleInsightResult>[];
    final attention = <VehicleAttention>[];

    if (!usingDemo) {
      for (final raw in v) {
        final map = raw as Map<String, dynamic>;
        final id = _vehicleIdFrom(map);
        final name = _vehicleName(map);
        if (id == MomentumApi.demoVehicleId) continue;
        try {
          final rows = await widget.api.vehicleData(id, limit: 1);
          if (rows.isNotEmpty) {
            final latest = rows.first as Map<String, dynamic>;
            insights.add(insightFromTelemetryRow(
              vehicleId: id,
              displayName: name,
              row: latest,
            ));
          }
          final maint = await widget.api.maintenanceRecommendations(id);
          for (final m in maint) {
            if (m is Map<String, dynamic>) {
              attention.addAll(
                mapMaintenanceRecommendationRow(vehicleLabel: name, raw: m),
              );
            }
          }
        } catch (_) {
          /* per-vehicle best-effort */
        }
      }
    }

    final obdInsight = insightFromObdLive(displayName: 'Live dongle');
    if (obdInsight != null) insights.add(obdInsight);

    for (final ins in insights) {
      attention.addAll(ins.telemetryAlerts);
    }
    attention.sort((a, b) {
      if (a.isUrgent != b.isUrgent) return a.isUrgent ? -1 : 1;
      return a.title.compareTo(b.title);
    });

    final fleet = rollupInsights(insights);

    if (!mounted) return;
    setState(() {
      _vehicles = v;
      _usingDemo = usingDemo;
      _lastRide = ride;
      _fleetRollup = fleet;
      _attention = attention;
      _loading = false;
    });
  }

  Future<void> _openLastRide() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const LastRideReportScreen(),
      ),
    );
    if (!mounted) return;
    RideRecord? ride;
    try {
      ride = await RideDb.instance.latestRide();
    } catch (_) {
      ride = null;
    }
    setState(() => _lastRide = ride);
  }

  Color _verdictAccent(BuildContext context, RideVerdict v) {
    final scheme = Theme.of(context).colorScheme;
    return switch (v) {
      RideVerdict.good => scheme.primary,
      RideVerdict.moderate => scheme.secondary,
      RideVerdict.harsh => scheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final scheme = Theme.of(context).colorScheme;
    final tab = widget.onNavigateToTab;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_usingDemo)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Server unreachable — garage data is limited; OBD + local ride history still work.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary),
              ),
            ),
          Text(
            'Live adapter, last trip quality, fleet health from latest server samples, and maintenance notes from the API.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Live OBD
          ListenableBuilder(
            listenable: ObdLiveStore.instance,
            builder: (context, _) {
              final o = ObdLiveStore.instance;
              final connected = o.elmConnected;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            connected ? Icons.bluetooth_connected : Icons.sensors_outlined,
                            color: connected ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Live vehicle status',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (connected && o.lastUpdate != null)
                            Text(
                              _shortTime(o.lastUpdate!),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        connected
                            ? (o.adapterLabel ?? 'Adapter connected')
                            : 'Not connected — open the OBD tab to pair your ELM327.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      if (connected) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metricChip(
                              context,
                              Icons.speed,
                              'Speed',
                              o.speedKph != null ? '${o.speedKph} km/h' : '—',
                            ),
                            _metricChip(
                              context,
                              Icons.trending_up,
                              'RPM',
                              o.rpm != null ? o.rpm!.toStringAsFixed(0) : '—',
                            ),
                            _metricChip(
                              context,
                              Icons.thermostat,
                              'Coolant',
                              o.coolantTempC != null ? '${o.coolantTempC!.toStringAsFixed(0)} °C' : '—',
                            ),
                            _metricChip(
                              context,
                              Icons.percent,
                              'Load',
                              o.engineLoadPct != null ? '${o.engineLoadPct!.toStringAsFixed(0)} %' : '—',
                            ),
                            if (o.harshBraking)
                              Chip(
                                avatar: Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
                                label: const Text('Harsh braking flag'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Last ride
          Card(
            child: InkWell(
              onTap: _openLastRide,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.route, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Last ride at a glance',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_lastRide == null)
                      Text(
                        'No saved trip yet — connect OBD, drive, then disconnect to store a summary; or use Demo on the OBD tab.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      )
                    else ...[
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: _verdictAccent(context, _lastRide!.verdict)
                                  .withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Text(
                                _lastRide!.verdict.name.toUpperCase(),
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: _verdictAccent(context, _lastRide!.verdict),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              mapVerdictLine(_lastRide!.verdict),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_lastRide!.sampleCount} samples · ended ${_fmtLocal(_lastRide!.endedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Fleet health
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_outline, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fleet health snapshot',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_fleetRollup.sourcesCount == 0)
                    Text(
                      _fleetRollup.summary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    )
                  else ...[
                    Row(
                      children: [
                        Text(
                          '${_fleetRollup.averageScore}',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (_fleetRollup.averageScore / 100).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: scheme.surfaceContainerHighest,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_fleetRollup.label} · ${_fleetRollup.summary}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_fleetRollup.worstInsight != null &&
                        _fleetRollup.worstInsight!.details.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '${_fleetRollup.worstInsight!.displayName} (${_fleetRollup.worstInsight!.healthLabel})',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      ..._fleetRollup.worstInsight!.details.take(3).map(
                            (line) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.subdirectory_arrow_right, size: 16, color: scheme.outline),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(line)),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Maintenance & attention
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_circle_outlined, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Maintenance & attention',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_attention.isEmpty)
                    Text(
                      'Nothing urgent from latest telemetry or saved maintenance suggestions. Pull to refresh after driving or syncing the server.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    )
                  else
                    Column(
                      children: [
                        for (final item in _attention.take(12))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              item.isUrgent ? Icons.error_outline : Icons.info_outline,
                              color: item.isUrgent ? scheme.error : scheme.primary,
                            ),
                            title: Text(item.title),
                            subtitle: Text('${item.vehicleLabel}\n${item.detail}'),
                            isThreeLine: true,
                          ),
                        if (_attention.length > 12 && tab != null)
                          TextButton.icon(
                            onPressed: () => tab(5),
                            icon: const Icon(Icons.more_horiz),
                            label: const Text('Shop tab for more suggestions'),
                          ),
                      ],
                    ),
                  if (tab != null) ...[
                    const Divider(height: 24),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => tab(1),
                          icon: const Icon(Icons.directions_car_outlined, size: 18),
                          label: const Text('Vehicles'),
                        ),
                        TextButton.icon(
                          onPressed: () => tab(5),
                          icon: const Icon(Icons.handyman_outlined, size: 18),
                          label: const Text('Shop / tips'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text('Vehicles linked: ${_vehicles.length}'),
              subtitle: Text(_usingDemo ? 'Demo fallback list' : 'Registered on the server'),
            ),
          ),
          const SizedBox(height: 12),
          ListenableBuilder(
            listenable: LocationStore.instance,
            builder: (context, _) {
              final loc = LocationStore.instance;
              final p = loc.position;
              final subtitle = loc.loading
                  ? 'Getting current location…'
                  : (loc.error != null)
                      ? loc.error!
                      : (p == null)
                          ? 'Tap refresh to request location'
                          : 'Lat ${p.latitude.toStringAsFixed(5)}, Lng ${p.longitude.toStringAsFixed(5)}';

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.my_location),
                  title: const Text('Current location'),
                  subtitle: Text(subtitle),
                  trailing: IconButton(
                    tooltip: 'Refresh location',
                    onPressed: loc.loading ? null : () => LocationStore.instance.refresh(),
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget _metricChip(BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 18, color: scheme.primary),
      label: Text('$label · $value', style: Theme.of(context).textTheme.bodySmall),
    );
  }

  static String _shortTime(DateTime t) {
    final now = DateTime.now();
    final d = now.difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtLocal(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
