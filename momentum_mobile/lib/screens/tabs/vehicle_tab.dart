import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../live/obd_live_store.dart';

class VehicleTab extends StatefulWidget {
  const VehicleTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<VehicleTab> createState() => _VehicleTabState();
}

class _VehicleTabState extends State<VehicleTab> {
  bool _loading = true;
  bool _usingDemo = false;
  List<dynamic> _vehicles = const [];
  String? _selectedId;
  List<dynamic> _samples = const [];

  String _vehicleIdFrom(Map<String, dynamic> v) => (v['_id'] ?? v['vehicle_id']).toString();

  void _onObdStoreChanged() {
    if (!context.mounted) return;
    if (_selectedId == MomentumApi.demoVehicleId) {
      setState(() => _samples = _demoSamples());
    }
  }

  @override
  void initState() {
    super.initState();
    ObdLiveStore.instance.addListener(_onObdStoreChanged);
    _refreshVehicles();
  }

  @override
  void dispose() {
    ObdLiveStore.instance.removeListener(_onObdStoreChanged);
    super.dispose();
  }

  /// Demo rows: static when OBD is off; live snapshot when ELM is connected.
  List<Map<String, dynamic>> _demoSamples() {
    final o = ObdLiveStore.instance;
    if (o.elmConnected && (o.speedKph != null || o.rpm != null)) {
      return [
        {
          'speed': (o.speedKph ?? 0).toDouble(),
          'rpm': (o.rpm ?? 0).toDouble(),
          'timestamp': (o.lastUpdate ?? DateTime.now()).toIso8601String(),
          'source': 'OBD',
        },
      ];
    }
    return [
      for (var i = 0; i < 5; i++)
        {
          'speed': 42.0 + i * 3,
          'rpm': 2200.0 - i * 40,
          'timestamp': DateTime.now().subtract(Duration(minutes: i * 2)).toIso8601String(),
          'source': 'demo',
        },
    ];
  }

  Future<void> _refreshVehicles() async {
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
      if (_selectedId == null && v.isNotEmpty) {
        _selectedId = _vehicleIdFrom(v.first as Map<String, dynamic>);
      } else if (_selectedId != null && v.isNotEmpty) {
        final ids = v.map((e) => _vehicleIdFrom(e as Map<String, dynamic>)).toSet();
        if (!ids.contains(_selectedId)) {
          _selectedId = _vehicleIdFrom(v.first as Map<String, dynamic>);
        }
      }
      _loading = false;
    });

    await _loadSamples();
  }

  Future<void> _loadSamples() async {
    final id = _selectedId;
    if (id == null) return;

    if (id == MomentumApi.demoVehicleId) {
      if (context.mounted) setState(() => _samples = _demoSamples());
      return;
    }

    try {
      final rows = await widget.api.vehicleData(id);
      if (context.mounted) setState(() => _samples = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _samples = const []);
    }
  }

  Future<void> _addVehicleDialog() async {
    final model = TextEditingController(text: 'Demo Sedan');
    final type = TextEditingController(text: 'sedan');
    final year = TextEditingController(text: '2020');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
            TextField(controller: type, decoration: const InputDecoration(labelText: 'Type')),
            TextField(controller: year, decoration: const InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        final created = await widget.api.createVehicle(
          model: model.text.trim(),
          type: type.text.trim(),
          year: int.tryParse(year.text.trim()),
        );
        setState(() {
          _selectedId = (created['_id'] ?? created['vehicle_id']).toString();
          _usingDemo = false;
        });
        await _refreshVehicles();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _simulateObdBurst() async {
    final id = _selectedId;
    if (id == null) return;
    if (id == MomentumApi.demoVehicleId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a vehicle on the server (Save in Add vehicle) to post simulated trips.')),
        );
      }
      return;
    }
    final rnd = Random();
    try {
      for (var i = 0; i < 25; i++) {
        final speed = 30 + rnd.nextDouble() * 60 + (i == 10 ? -25 : 0);
        final rpm = 1800 + rnd.nextInt(1200) + (i == 15 ? 800 : 0);
        await widget.api.postVehicleData(vehicleId: id, speed: speed, rpm: rpm.toDouble(), fuelConsumption: 7 + rnd.nextDouble());
      }
      await _loadSamples();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Posted 25 simulated OBD samples')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  static String _fmtNum(dynamic v, [int decimals = 1]) {
    if (v == null) return '—';
    if (v is num) return v.toDouble().toStringAsFixed(decimals);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final selected = _selectedId;

    return Column(
      children: [
        if (_usingDemo)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Offline demo vehicle — open the OBD tab and connect to show live speed/RPM here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String?>('${selected ?? ''}-${_vehicles.length}'),
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
                  items: _vehicles
                      .map(
                        (v) => DropdownMenuItem<String>(
                          value: _vehicleIdFrom(v as Map<String, dynamic>),
                          child: Text('${v['vehicle_model']} (${v['vehicle_type']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (x) async {
                    setState(() => _selectedId = x);
                    await _loadSamples();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: _addVehicleDialog, icon: const Icon(Icons.add)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: selected == null ? null : _simulateObdBurst,
                  icon: const Icon(Icons.sensors),
                  label: const Text('Simulate OBD burst'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(onPressed: _loadSamples, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: _samples.isEmpty
              ? const Center(child: Text('No samples yet — add a vehicle and simulate OBD data, or open the OBD tab.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _samples.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _samples[_samples.length - 1 - i] as Map<String, dynamic>;
                    final src = r['source'];
                    final extra = src != null ? ' · $src' : '';
                    return ListTile(
                      dense: true,
                      title: Text('Speed ${_fmtNum(r['speed'])} km/h · RPM ${_fmtNum(r['rpm'], 0)}$extra'),
                      subtitle: Text('${r['timestamp']}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
