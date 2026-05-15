import 'dart:convert';

class Vehicle {
  final String id;
  final String model;
  final String type;
  final int year;
  final String? vin;
  final double health; // 0.0 to 1.0
  final double fuelAverage;
  final List<String> tirePressures;
  final String lastDrivingStatus; // 'Good', 'Harsh', 'Moderate'
  final DateTime? lastDrivenAt;
  final List<MaintenanceRecord> maintenanceHistory;

  Vehicle({
    required this.id,
    required this.model,
    required this.type,
    required this.year,
    this.vin,
    this.health = 0.95,
    this.fuelAverage = 12.5,
    this.tirePressures = const ['32', '32', '31', '32'],
    this.lastDrivingStatus = 'Good',
    this.lastDrivenAt,
    this.maintenanceHistory = const [],
  });

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: (map['_id'] ?? map['vehicle_id'] ?? '').toString(),
      model: map['vehicle_model'] ?? 'Unknown Model',
      type: map['vehicle_type'] ?? 'Unknown Type',
      year: map['year'] ?? DateTime.now().year,
      vin: map['vin'],
      // Defaults for now as backend might not have these yet
      health: map['health']?.toDouble() ?? 0.92,
      fuelAverage: map['fuel_average']?.toDouble() ?? 14.2,
      tirePressures: map['tire_pressures'] != null 
          ? List<String>.from(map['tire_pressures']) 
          : const ['32', '32', '31', '32'],
      lastDrivingStatus: map['last_driving_status'] ?? 'Good',
      lastDrivenAt: map['last_driven_at'] != null 
          ? DateTime.tryParse(map['last_driven_at']) 
          : null,
      maintenanceHistory: map['maintenance_history'] != null
          ? (map['maintenance_history'] as List)
              .map((e) => MaintenanceRecord.fromMap(e))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'vehicle_model': model,
      'vehicle_type': type,
      'year': year,
      'vin': vin,
      'health': health,
      'fuel_average': fuelAverage,
      'tire_pressures': tirePressures,
      'last_driving_status': lastDrivingStatus,
      'last_driven_at': lastDrivenAt?.toIso8601String(),
    };
  }
}

class MaintenanceRecord {
  final String type; // 'Oil Change', 'Tuning', 'Tire Rotation', etc.
  final DateTime date;
  final double mileage;
  final String notes;

  MaintenanceRecord({
    required this.type,
    required this.date,
    required this.mileage,
    this.notes = '',
  });

  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      type: map['type'] ?? 'Service',
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      mileage: map['mileage']?.toDouble() ?? 0,
      notes: map['notes'] ?? '',
    );
  }
}
