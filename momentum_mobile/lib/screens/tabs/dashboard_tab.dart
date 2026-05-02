import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../live/obd_live_store.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _loading = true;
  bool _usingDemo = false;
  List<dynamic> _vehicles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!context.mounted) return;
    setState(() {
      _loading = true;
      _usingDemo = false;
    });
    List<dynamic> v;
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
    if (!context.mounted) return;
    setState(() {
      _vehicles = v;
      _usingDemo = usingDemo;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return ListenableBuilder(
      listenable: ObdLiveStore.instance,
      builder: (context, _) {
        final o = ObdLiveStore.instance;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text('Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_usingDemo)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Server unreachable — showing demo vehicle count. Connect OBD for live gauges.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              Text(
                'Momentum links OBD-style telemetry, driving behaviour, commute context, and optional route sharing. '
                'Use the Vehicle tab to register a car and simulate samples before running analysis.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car),
                  title: Text('Vehicles linked: ${_vehicles.length}'),
                  subtitle: Text(_usingDemo ? 'Demo mode' : 'Add a vehicle, ingest OBD samples, then open Analysis.'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            o.elmConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: o.elmConnected ? Theme.of(context).colorScheme.primary : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              o.elmConnected ? 'OBD dongle connected' : 'OBD not connected',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      if (o.elmConnected && (o.adapterLabel ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          o.adapterLabel!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        o.elmConnected
                            ? 'Speed: ${o.speedKph ?? '—'} km/h · RPM: ${o.rpm == null ? '—' : o.rpm!.toStringAsFixed(0)}'
                            : 'Open the OBD tab, pair your ELM327, and tap Connect — live values appear here.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
