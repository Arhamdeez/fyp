/// Orchestrates backend API + weather fetch → produces list of [RouteOption].
library;

import 'dart:developer' as developer;
import 'dart:math' as math;

import '../../api/momentum_api.dart';
import '../models/route_model.dart';
import 'weather_service.dart';

class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// Fetch route insights from the backend + weather, then synthesize
  /// 4 [RouteOption] variants.
  Future<List<RouteOption>> fetchRoutes({
    required MomentumApi api,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String originName,
    required String destName,
  }) async {
    // Retry wrapper for API insights
    Map<String, dynamic>? insights;
    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        final results = await Future.wait([
          api.routeInsights(
            destLat: destLat,
            destLng: destLng,
            originLat: originLat,
            originLng: originLng,
          ),
          if (attempts == 1) WeatherService.instance.fetchWeather(lat: originLat, lng: originLng),
        ]);
        insights = results[0] as Map<String, dynamic>;
        break; // Success
      } catch (e, st) {
        developer.log('Route insights attempt $attempts failed: $e', name: 'RouteService', error: e, stackTrace: st);
        if (attempts >= 2) {
          developer.log('Falling back to local haversine/ETA calculations', name: 'RouteService');
          break; // Don't rethrow. Fallback to local math logic.
        }
        await Future.delayed(Duration(seconds: attempts * 2)); // Exponential backoff
      }
    }

    final weather = await WeatherService.instance.fetchWeather(lat: originLat, lng: originLng);
    insights ??= {}; // Should not reach here if rethrow happens, but just in case

    // ── Parse/estimate distance & ETA from backend or haversine ──────────
    final distanceKm = _parseDoubleField(insights, [
          'distance_km',
          'distance',
          'dist_km',
        ]) ??
        _haversineKm(originLat, originLng, destLat, destLng);

    final baseEta = _parseIntField(insights, [
          'eta_minutes',
          'eta',
          'duration_minutes',
        ]) ??
        _estimateEta(distanceKm, TrafficLevel.moderate);

    final drivingTip = insights['driving_tip']?.toString() ??
        insights['tip']?.toString() ??
        'Stay alert and follow traffic signals.';

    final weatherNote = insights['weather_note']?.toString() ?? '';
    final summaryText = insights['summary']?.toString() ?? '';

    // ── Derive traffic from summary/weather_note heuristic ────────────────
    final traffic = _parseTrafficFromText(
      '$summaryText $weatherNote',
      distanceKm,
    );

    // ── Build 4 route variants ────────────────────────────────────────────
    return [
      _buildRoute(
        type: RouteType.fastest,
        title: 'Fastest Route',
        subtitle: 'Shortest travel time',
        distanceKm: distanceKm * 1.0,
        baseEta: baseEta,
        trafficMultiplier: 1.0,
        weather: weather,
        traffic: traffic,
        drivingTip: drivingTip,
        originName: originName,
        destName: destName,
      ),
      _buildRoute(
        type: RouteType.eco,
        title: 'Eco-Friendly Route',
        subtitle: 'Saves fuel & reduces emissions',
        distanceKm: distanceKm * 1.08,
        baseEta: (baseEta * 1.12).round(),
        trafficMultiplier: 0.7,
        weather: weather,
        traffic: _lowerTraffic(traffic),
        drivingTip: 'Maintain steady speed to maximise fuel efficiency.',
        originName: originName,
        destName: destName,
      ),
      _buildRoute(
        type: RouteType.leastTraffic,
        title: 'Least Traffic Route',
        subtitle: 'Avoid congestion & delays',
        distanceKm: distanceKm * 1.15,
        baseEta: (baseEta * 0.95).round(),
        trafficMultiplier: 0.4,
        weather: weather,
        traffic: _minTraffic(traffic),
        drivingTip: 'Side roads are clear — enjoy the smooth drive.',
        originName: originName,
        destName: destName,
      ),
      _buildRoute(
        type: RouteType.recommended,
        title: 'Recommended Route',
        subtitle: 'Best balance of speed & safety',
        distanceKm: distanceKm * 1.05,
        baseEta: (baseEta * 1.03).round(),
        trafficMultiplier: 0.85,
        weather: weather,
        traffic: traffic,
        drivingTip: drivingTip,
        originName: originName,
        destName: destName,
        boostedScore: true,
      ),
    ];
  }

  // ── Internal builders ───────────────────────────────────────────────────

  RouteOption _buildRoute({
    required RouteType type,
    required String title,
    required String subtitle,
    required double distanceKm,
    required int baseEta,
    required double trafficMultiplier,
    required WeatherInfo weather,
    required TrafficInfo traffic,
    required String drivingTip,
    required String originName,
    required String destName,
    bool boostedScore = false,
  }) {
    final vehicleRec = _recommendVehicle(
      distanceKm: distanceKm,
      weather: weather,
      traffic: traffic,
      isEco: type == RouteType.eco,
    );

    final safetyScore = _calcSafety(weather, traffic);
    final smartScore = _calcSmartScore(
      type: type,
      safety: safetyScore,
      traffic: traffic,
      distanceKm: distanceKm,
      boosted: boostedScore,
    );

    final fuelEff = _fuelLabel(type, traffic);

    return RouteOption(
      type: type,
      title: title,
      subtitle: subtitle,
      distanceKm: distanceKm,
      etaMinutes: baseEta + (traffic.delayMinutes * trafficMultiplier).round(),
      weather: weather,
      traffic: traffic,
      vehicleRec: vehicleRec,
      safetyScore: safetyScore,
      smartScore: smartScore,
      fuelEfficiencyLabel: fuelEff,
      drivingTip: drivingTip,
      originName: originName,
      destName: destName,
    );
  }

  VehicleRecommendation _recommendVehicle({
    required double distanceKm,
    required WeatherInfo weather,
    required TrafficInfo traffic,
    required bool isEco,
  }) {
    // Rain → always recommend car
    if (weather.isRaining) {
      return const VehicleRecommendation(
        vehicle: VehicleType.car,
        reason: 'Rainy conditions — car provides shelter and safety',
        confidence: 0.95,
      );
    }

    // Walking distance
    if (distanceKm < 0.8) {
      return const VehicleRecommendation(
        vehicle: VehicleType.walk,
        reason: 'Very short distance — walking is fastest',
        confidence: 0.9,
      );
    }

    // Eco route → prefer bicycle/motorcycle
    if (isEco && distanceKm < 8) {
      return const VehicleRecommendation(
        vehicle: VehicleType.bicycle,
        reason: 'Eco route — zero emissions, no traffic',
        confidence: 0.85,
      );
    }

    // Short + clear → motorcycle
    if (distanceKm < 12 && !weather.isHazardous) {
      if (traffic.level == TrafficLevel.heavy) {
        return const VehicleRecommendation(
          vehicle: VehicleType.motorcycle,
          reason: 'Heavy traffic — motorcycle can navigate gaps efficiently',
          confidence: 0.88,
        );
      }
      return const VehicleRecommendation(
        vehicle: VehicleType.motorcycle,
        reason: 'Short urban distance — motorcycle is quick and fuel-efficient',
        confidence: 0.82,
      );
    }

    // Long distance or bad conditions → car
    if (distanceKm > 30 || weather.isHazardous) {
      return VehicleRecommendation(
        vehicle: VehicleType.car,
        reason: distanceKm > 30
            ? 'Long distance — car provides comfort and fuel efficiency'
            : 'Adverse conditions — car is safest option',
        confidence: 0.9,
      );
    }

    // Default moderate → car
    return const VehicleRecommendation(
      vehicle: VehicleType.car,
      reason: 'Balanced choice for this route distance and conditions',
      confidence: 0.75,
    );
  }

  int _calcSafety(WeatherInfo w, TrafficInfo t) {
    var score = 100;
    if (w.isRaining) score -= 20;
    if (w.isFoggy) score -= 15;
    if (w.windKph > 40) score -= 10;
    if (t.level == TrafficLevel.heavy) score -= 20;
    if (t.level == TrafficLevel.moderate) score -= 10;
    return score.clamp(30, 100);
  }

  int _calcSmartScore({
    required RouteType type,
    required int safety,
    required TrafficInfo traffic,
    required double distanceKm,
    required bool boosted,
  }) {
    var base = safety;
    base += switch (type) {
      RouteType.fastest => 5,
      RouteType.eco => 8,
      RouteType.leastTraffic => 6,
      RouteType.recommended => 10,
    };
    if (traffic.level == TrafficLevel.low) base += 5;
    if (boosted) base += 8;
    return base.clamp(0, 100);
  }

  String _fuelLabel(RouteType type, TrafficInfo traffic) {
    if (type == RouteType.eco) return 'Excellent';
    if (type == RouteType.leastTraffic) return 'Good';
    if (traffic.level == TrafficLevel.heavy) return 'Poor';
    if (traffic.level == TrafficLevel.moderate) return 'Fair';
    return 'Good';
  }

  // ── Traffic helpers ─────────────────────────────────────────────────────

  TrafficInfo _parseTrafficFromText(String text, double distanceKm) {
    final lower = text.toLowerCase();
    TrafficLevel level;
    if (lower.contains('heavy') ||
        lower.contains('congestion') ||
        lower.contains('jam')) {
      level = TrafficLevel.heavy;
    } else if (lower.contains('moderate') ||
        lower.contains('slow') ||
        lower.contains('busy')) {
      level = TrafficLevel.moderate;
    } else {
      level = TrafficLevel.low;
    }
    return TrafficInfo(
      level: level,
      delayMinutes: switch (level) {
        TrafficLevel.low => 0,
        TrafficLevel.moderate => (distanceKm * 0.8).round().clamp(2, 15),
        TrafficLevel.heavy => (distanceKm * 1.5).round().clamp(5, 45),
      },
      congestionPct: switch (level) {
        TrafficLevel.low => 15,
        TrafficLevel.moderate => 50,
        TrafficLevel.heavy => 82,
      },
      description: switch (level) {
        TrafficLevel.low => 'Roads are clear',
        TrafficLevel.moderate => 'Some congestion along route',
        TrafficLevel.heavy => 'Heavy congestion detected',
      },
    );
  }

  TrafficInfo _lowerTraffic(TrafficInfo t) => TrafficInfo(
        level: t.level == TrafficLevel.heavy
            ? TrafficLevel.moderate
            : TrafficLevel.low,
        delayMinutes: (t.delayMinutes * 0.5).round(),
        congestionPct: (t.congestionPct * 0.5).round(),
        description: 'Less congestion on eco route',
      );

  TrafficInfo _minTraffic(TrafficInfo t) => TrafficInfo(
        level: TrafficLevel.low,
        delayMinutes: 0,
        congestionPct: (t.congestionPct * 0.2).round(),
        description: 'Minimal traffic on alternate roads',
      );

  // ── Utility ─────────────────────────────────────────────────────────────

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  static int _estimateEta(double km, TrafficLevel traffic) {
    // Average speed estimates
    final avgKph = switch (traffic) {
      TrafficLevel.low => 45.0,
      TrafficLevel.moderate => 30.0,
      TrafficLevel.heavy => 18.0,
    };
    return ((km / avgKph) * 60).round().clamp(1, 300);
  }

  static double? _parseDoubleField(
      Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) return (v as num).toDouble();
    }
    return null;
  }

  static int? _parseIntField(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null) return (v as num).round();
    }
    return null;
  }
}
