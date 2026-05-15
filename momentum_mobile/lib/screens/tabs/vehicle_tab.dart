import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

  Future<void> _refreshVehicles({bool silent = false}) async {
    if (!context.mounted) return;
    if (!silent) setState(() => _loading = true);

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
        setState(() {
          if (!silent) _loading = false;
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _upsertVehicleInState(Vehicle vehicle) {
    if (!mounted || vehicle.id.isEmpty) return;
    final merged = {for (final v in _vehicles) v.id: v};
    merged[vehicle.id] = vehicle;
    setState(() => _vehicles = merged.values.toList());
  }

  bool _shouldSaveVehicleLocallyOnError(Object e) {
    if (e is ApiException) {
      final c = e.statusCode;
      if (c == 401 || c == 403) return false;
      if (c != null && c >= 400 && c < 500) return false;
      return true;
    }
    return true;
  }

  String _addVehicleErrorMessage(Object e) {
    if (e is ApiException) {
      final c = e.statusCode;
      if (c == 401 || c == 403) {
        return 'Could not add on server — sign in again or check your session.';
      }
      if (c != null && c >= 400 && c < 500) {
        return 'Could not add: ${e.message}';
      }
      return 'Could not reach server — ${e.message}';
    }
    if (e is TimeoutException) {
      return 'Request timed out — check Wi‑Fi and that the API server is running.';
    }
    if (e is SocketException || e is http.ClientException) {
      return 'No network connection to the server — check the API address (e.g. LAN IP on a real phone).';
    }
    return 'Could not add vehicle: $e';
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
        final created = await widget.api.createVehicle(
          model: vModel,
          type: vType,
          year: vYear,
        );
        // Keep a local copy so the garage updates even if GET /vehicles fails next
        // (timeouts, flaky Wi‑Fi, token issues). Otherwise the new row can vanish.
        final vehicle = Vehicle.fromMap(created);
        if (vehicle.id.isNotEmpty) {
          await LocalVehicleStore.instance.saveVehicle(vehicle);
          _upsertVehicleInState(vehicle);
        }
        // Silent refresh avoids a full-screen spinner and waits less on a slow/dead API.
        await _refreshVehicles(silent: true);
      } catch (e) {
        if (_shouldSaveVehicleLocallyOnError(e)) {
          final localV = Vehicle(
            id: 'local-${DateTime.now().millisecondsSinceEpoch}',
            model: vModel,
            type: vType,
            year: vYear,
            lastDrivenAt: DateTime.now(),
          );
          await LocalVehicleStore.instance.saveVehicle(localV);
          _upsertVehicleInState(localV);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${_addVehicleErrorMessage(e)} Saved on this device; you can sync when the server is available.',
                ),
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_addVehicleErrorMessage(e))),
          );
        }
        await _refreshVehicles(silent: true);
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
      
      await _refreshVehicles(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _refreshVehicles(silent: true),
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
