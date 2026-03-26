import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';

class VehicleTab extends StatefulWidget {
  const VehicleTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<VehicleTab> createState() => _VehicleTabState();
}

class _VehicleTabState extends State<VehicleTab> {
  bool _loading = true;
  String? _error;
  List<dynamic> _vehicles = const [];
  int? _selectedId;
  List<dynamic> _samples = const [];

  @override
  void initState() {
    super.initState();
    _refreshVehicles();
  }

  Future<void> _refreshVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final v = await widget.api.vehicles();
      setState(() {
        _vehicles = v;
        if (_selectedId == null && v.isNotEmpty) {
          _selectedId = (v.first as Map<String, dynamic>)['vehicle_id'] as int;
        }
      });
      if (_selectedId != null) await _loadSamples();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSamples() async {
    final id = _selectedId;
    if (id == null) return;
    try {
      final rows = await widget.api.vehicleData(id);
      setState(() => _samples = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
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
          _selectedId = created['vehicle_id'] as int;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedId,
                  decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
                  items: _vehicles
                      .map(
                        (v) => DropdownMenuItem<int>(
                          value: (v as Map<String, dynamic>)['vehicle_id'] as int,
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
                  onPressed: _selectedId == null ? null : _simulateObdBurst,
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
              ? const Center(child: Text('No samples yet — add a vehicle and simulate OBD data.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _samples.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _samples[_samples.length - 1 - i] as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      title: Text('Speed ${r['speed']?.toStringAsFixed(1)} km/h · RPM ${r['rpm']?.toStringAsFixed(0)}'),
                      subtitle: Text('${r['timestamp']}'),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
