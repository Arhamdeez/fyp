/// Core data models for the Routes feature.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum RouteType {
  fastest,
  eco,
  leastTraffic,
  recommended,
}

enum TrafficLevel {
  low,
  moderate,
  heavy,
}

enum VehicleType {
  bicycle,
  motorcycle,
  car,
  walk,
}

// ─────────────────────────────────────────────────────────────────────────────
// WeatherInfo
// ─────────────────────────────────────────────────────────────────────────────

class WeatherInfo {
  const WeatherInfo({
    required this.condition,
    required this.tempC,
    required this.windKph,
    required this.rainMmPerHour,
    required this.iconCode,
    required this.description,
  });

  final String condition;      // e.g. "Clear", "Rain", "Fog"
  final double tempC;
  final double windKph;
  final double rainMmPerHour;
  final String iconCode;       // OWM icon code e.g. "01d"
  final String description;   // human-readable

  bool get isRaining => rainMmPerHour > 0.5;
  bool get isFoggy => condition.toLowerCase().contains('fog') ||
      condition.toLowerCase().contains('mist') ||
      condition.toLowerCase().contains('haze');
  bool get isHazardous => isRaining || isFoggy || windKph > 40;

  String get warningText {
    if (rainMmPerHour > 5) return 'Heavy rain expected — drive carefully';
    if (rainMmPerHour > 0.5) return 'Light rain — roads may be slippery';
    if (isFoggy) return 'Reduced visibility — fog detected';
    if (windKph > 40) return 'Strong winds — caution advised';
    return 'Clear driving conditions';
  }

  static WeatherInfo unavailable() => const WeatherInfo(
        condition: 'Unknown',
        tempC: 0,
        windKph: 0,
        rainMmPerHour: 0,
        iconCode: '01d',
        description: 'Weather unavailable',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TrafficInfo
// ─────────────────────────────────────────────────────────────────────────────

class TrafficInfo {
  const TrafficInfo({
    required this.level,
    required this.delayMinutes,
    required this.congestionPct,
    required this.description,
  });

  final TrafficLevel level;
  final int delayMinutes;
  final int congestionPct; // 0–100
  final String description;

  String get levelLabel => switch (level) {
        TrafficLevel.low => 'Low Traffic',
        TrafficLevel.moderate => 'Moderate Traffic',
        TrafficLevel.heavy => 'Heavy Traffic',
      };

  String get delayLabel => delayMinutes == 0
      ? 'No delay'
      : '+$delayMinutes min delay';
}

// ─────────────────────────────────────────────────────────────────────────────
// VehicleRecommendation
// ─────────────────────────────────────────────────────────────────────────────

class VehicleRecommendation {
  const VehicleRecommendation({
    required this.vehicle,
    required this.reason,
    required this.confidence, // 0.0–1.0
  });

  final VehicleType vehicle;
  final String reason;
  final double confidence;

  String get vehicleLabel => switch (vehicle) {
        VehicleType.bicycle => 'Bicycle',
        VehicleType.motorcycle => 'Motorcycle',
        VehicleType.car => 'Car',
        VehicleType.walk => 'Walking',
      };

  String get confidenceLabel {
    if (confidence >= 0.8) return 'High confidence';
    if (confidence >= 0.5) return 'Moderate confidence';
    return 'Low confidence';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RouteOption
// ─────────────────────────────────────────────────────────────────────────────

class RouteOption {
  const RouteOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.distanceKm,
    required this.etaMinutes,
    required this.weather,
    required this.traffic,
    required this.vehicleRec,
    required this.safetyScore,
    required this.smartScore,
    required this.fuelEfficiencyLabel,
    required this.drivingTip,
    required this.originName,
    required this.destName,
  });

  final RouteType type;
  final String title;
  final String subtitle;
  final double distanceKm;
  final int etaMinutes;
  final WeatherInfo weather;
  final TrafficInfo traffic;
  final VehicleRecommendation vehicleRec;
  final int safetyScore;   // 0–100
  final int smartScore;    // 0–100 overall route quality
  final String fuelEfficiencyLabel; // e.g. "Excellent", "Good", "Poor"
  final String drivingTip;
  final String originName;
  final String destName;

  String get etaLabel {
    if (etaMinutes < 60) return '$etaMinutes min';
    final h = etaMinutes ~/ 60;
    final m = etaMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String get distanceLabel => distanceKm < 1
      ? '${(distanceKm * 1000).round()} m'
      : '${distanceKm.toStringAsFixed(1)} km';
}

// ─────────────────────────────────────────────────────────────────────────────
// LoadingPhase
// ─────────────────────────────────────────────────────────────────────────────

enum LoadingPhase {
  idle,
  locating,
  fetchingInsights,
  fetchingWeather,
  analyzing,
  done,
}

extension LoadingPhaseLabel on LoadingPhase {
  String get message => switch (this) {
        LoadingPhase.idle => '',
        LoadingPhase.locating => 'Getting your location…',
        LoadingPhase.fetchingInsights => 'Finding best routes…',
        LoadingPhase.fetchingWeather => 'Checking weather conditions…',
        LoadingPhase.analyzing => 'Optimizing recommendations…',
        LoadingPhase.done => '',
      };

  bool get isLoading => this != LoadingPhase.idle && this != LoadingPhase.done;
}
