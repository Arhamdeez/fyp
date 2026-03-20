import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _vehicles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await widget.api.vehicles();
      setState(() => _vehicles = v);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
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
              subtitle: const Text('Add a vehicle, ingest OBD samples, then open Analysis.'),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.bluetooth_connected),
              title: Text('OBD-II'),
              subtitle: Text('Production builds can pair a BLE/USB ELM327 adapter; this prototype posts JSON readings to the API.'),
            ),
          ),
        ],
      ),
    );
  }
}
