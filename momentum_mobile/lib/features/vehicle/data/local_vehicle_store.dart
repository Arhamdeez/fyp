import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/vehicle.dart';

class LocalVehicleStore {
  LocalVehicleStore._();
  static final LocalVehicleStore instance = LocalVehicleStore._();

  static const String _kKey = 'local_vehicles';

  Future<List<Vehicle>> getVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? raw = prefs.getStringList(_kKey);
    if (raw == null) return [];
    return raw.map((e) => Vehicle.fromMap(jsonDecode(e))).toList();
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Vehicle> current = await getVehicles();
    current.removeWhere((e) => e.id == vehicle.id);
    current.add(vehicle);
    await prefs.setStringList(_kKey, current.map((e) => jsonEncode(e.toMap())).toList());
  }

  Future<void> removeVehicle(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Vehicle> current = await getVehicles();
    current.removeWhere((e) => e.id == id);
    await prefs.setStringList(_kKey, current.map((e) => jsonEncode(e.toMap())).toList());
  }
}
