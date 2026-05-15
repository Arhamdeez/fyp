import 'dart:math';

import 'package:flutter/material.dart';

import '../../api/momentum_api.dart';
import '../../features/vehicle/domain/entities/vehicle.dart';
import '../../motion/app_motion.dart';
import '../vehicle_detail_screen.dart';
import 'vehicle_card.dart';
import '../../features/vehicle/data/local_vehicle_store.dart';

class VehicleTab extends StatefulWidget {
  const VehicleTab({super.key, required this.api});

  final MomentumApi api;

  @override
  State<VehicleTab> createState() => _VehicleTabState();
}

class _VehicleTabState extends State<VehicleTab> {
  bool _loading = true;
  List<Vehicle> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _refreshVehicles();
  }

  Future<void> _refreshVehicles() async {
    if (!context.mounted) return;
    setState(() => _loading = true);

    try {
      final List<Vehicle> local = await LocalVehicleStore.instance.getVehicles();
      List<Vehicle> remote = [];
      
      try {
        final List<dynamic> raw = await widget.api.vehicles();
        remote = raw.map((e) => Vehicle.fromMap(e as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Remote fetch failed (probably offline): $e');
      }

      // Merge and remove duplicates by ID
      final Map<String, Vehicle> merged = {};
      for (var v in local) { merged[v.id] = v; }
      for (var v in remote) { merged[v.id] = v; }
      
      final List<Vehicle> list = merged.values.toList();
      
      // Ensure we have at least 1 demo vehicle if empty
      if (list.isEmpty) {
        list.add(Vehicle.fromMap(MomentumApi.dummyVehicles().first as Map<String, dynamic>));
      }

      if (mounted) {
        setState(() {
          _vehicles = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addVehicleDialog() async {
    final model = TextEditingController(text: 'My Honda Civic');
    final type = TextEditingController(text: 'Sedan');
    final year = TextEditingController(text: '2022');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Vehicle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: model, decoration: const InputDecoration(labelText: 'Model (e.g. Civic)')),
            const SizedBox(height: 12),
            TextField(controller: type, decoration: const InputDecoration(labelText: 'Type (e.g. Sedan, SUV)')),
            const SizedBox(height: 12),
            TextField(controller: year, decoration: const InputDecoration(labelText: 'Year'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add Vehicle')),
        ],
      ),
    );

    if (ok == true && mounted) {
      final vModel = model.text.trim();
      final vType = type.text.trim();
      final vYear = int.tryParse(year.text.trim()) ?? 2022;

      try {
        await widget.api.createVehicle(
          model: vModel,
          type: vType,
          year: vYear,
        );
        _refreshVehicles();
      } catch (e) {
        // If it's a socket exception or client exception, save locally
        final localV = Vehicle(
          id: 'local-${DateTime.now().millisecondsSinceEpoch}',
          model: vModel,
          type: vType,
          year: vYear,
          lastDrivenAt: DateTime.now(),
        );
        await LocalVehicleStore.instance.saveVehicle(localV);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Server unreachable. Vehicle saved locally (Offline mode).')),
          );
        }
        _refreshVehicles();
      }
    }
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text('Are you sure you want to remove ${v.model}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      // Always remove from local store if it's there
      await LocalVehicleStore.instance.removeVehicle(v.id);
      
      try {
        await widget.api.deleteVehicle(v.id);
      } catch (e) {
        debugPrint('Failed to delete from server (offline): $e');
      }
      
      _refreshVehicles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshVehicles,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Garage',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'You have ${_vehicles.length} active vehicles',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      IconButton.filledTonal(
                        onPressed: _addVehicleDialog,
                        icon: const Icon(Icons.add),
                        tooltip: 'Add new vehicle',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ..._vehicles.map((v) => VehicleCard(
                        vehicle: v,
                        onTap: () => Navigator.push(
                          context,
                          fadeSlidePageRoute(VehicleDetailScreen(vehicle: v, api: widget.api)),
                        ),
                        onDelete: () => _deleteVehicle(v),
                      )),
                  if (_vehicles.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: [
                            Icon(Icons.directions_car_filled_outlined, size: 64, color: scheme.outline),
                            const SizedBox(height: 16),
                            const Text('No vehicles added yet'),
                            TextButton(onPressed: _addVehicleDialog, child: const Text('Add your first vehicle')),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
