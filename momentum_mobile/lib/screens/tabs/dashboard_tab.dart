import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../live/location_store.dart';
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
    // Fetch location opportunistically; UI stays usable if denied/off.
    LocationStore.instance.refresh();
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
                'Server unreachable — showing demo vehicle count.',
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
}
