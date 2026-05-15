import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Default for reads and background calls (fail faster than the old 25s wait).
const Duration _kHttpTimeout = Duration(seconds: 12);

/// Writes like add-vehicle: short wait so the UI does not hang on a dead host.
const Duration _kHttpWriteTimeout = Duration(seconds: 7);

String _sanitizeBaseUrl(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), '');

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class MomentumApi {
  MomentumApi({String? baseUrl}) : baseUrl = _sanitizeBaseUrl(baseUrl ?? momentumApiBaseUrl());

  final String baseUrl;
  String? bearerToken;

  /// Legacy fixed id (still treated as demo via [isOfflineDemoVehicleId]).
  static const String demoVehicleId = 'local-demo-vehicle';

  static final Random _demoRnd = Random();

  /// True for synthetic garage rows (random offline demo or the legacy fixed id).
  static bool isOfflineDemoVehicleId(String id) =>
      id == demoVehicleId || id.startsWith('local-demo-');

  /// Random placeholder when the API has no vehicles or is unreachable.
  static List<dynamic> dummyVehicles() {
    final r = _demoRnd;
    const models = [
      'Civic', 'Corolla', 'Camry', 'Accord', 'Model 3', 'Leaf', 'F-150', 'RAV4',
      'CX-5', 'Outback', 'Elantra', 'Sentra', 'Altima', 'Wrangler', 'Bronco',
    ];
    const types = ['Sedan', 'SUV', 'Truck', 'Hatchback', 'EV', 'Crossover'];
    final model = models[r.nextInt(models.length)];
    final type = types[r.nextInt(types.length)];
    final year = 2015 + r.nextInt(12);
    final id = 'local-demo-${DateTime.now().microsecondsSinceEpoch}-${r.nextInt(1 << 20)}';
    final vin = 'DEMO${List.generate(11, (_) => r.nextInt(10)).join()}';
    return [
      <String, dynamic>{
        '_id': id,
        'vehicle_model': '$model (demo)',
        'vehicle_type': type,
        'year': year,
        'vin': vin,
      },
    ];
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
      };

  Future<Map<String, dynamic>> _jsonOrThrow(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return {};
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    String msg = r.body;
    try {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      msg = m['detail']?.toString() ?? m['message']?.toString() ?? r.body;
    } catch (_) {}
    throw ApiException(msg, statusCode: r.statusCode);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final r = await _post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
    );
    await _jsonOrThrow(r);
  }

  Future<String> login({required String email, required String password}) async {
    final r = await _post('/auth/login', body: {'email': email, 'password': password});
    final m = await _jsonOrThrow(r);
    return (m['token'] ?? m['access_token']) as String;
  }

  Future<http.Response> _get(String path, {Duration? timeout}) =>
      http.get(Uri.parse('$baseUrl$path'), headers: _headers).timeout(timeout ?? _kHttpTimeout);

  Future<http.Response> _post(String path, {Object? body, Duration? timeout}) => http
      .post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: body is String ? body : (body != null ? jsonEncode(body) : null),
      )
      .timeout(timeout ?? _kHttpTimeout);

  static List<dynamic> _decodeVehicleList(Object? raw) {
    if (raw is List<dynamic>) return raw;
    if (raw is List) return raw;
    return const [];
  }

  Future<List<dynamic>> vehicles() async {
    late final http.Response r;
    try {
      r = await _get('/vehicles');
    } on TimeoutException {
      throw ApiException('Request timed out — check network and API URL.', statusCode: null);
    }
    Object? raw;
    try {
      raw = r.body.isEmpty ? const <dynamic>[] : jsonDecode(r.body);
    } catch (_) {
      raw = const <dynamic>[];
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return _decodeVehicleList(raw);
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> createVehicle({
    required String model,
    required String type,
    int? year,
    String? vin,
  }) async {
    final y = year ?? DateTime.now().year;
    final v = vin ?? 'DEMO${DateTime.now().millisecondsSinceEpoch}';
    late final http.Response r;
    try {
      r = await _post(
        '/vehicles',
        body: {
          'vehicle_model': model,
          'vehicle_type': type,
          'year': y,
          'vin': v,
        },
        timeout: _kHttpWriteTimeout,
      );
    } on TimeoutException {
      throw ApiException('Request timed out — check network and API URL.', statusCode: null);
    }
    return _jsonOrThrow(r);
  }

  Future<void> deleteVehicle(String vehicleId) async {
    final r = await http.delete(
      Uri.parse('$baseUrl/vehicles/$vehicleId'),
      headers: _headers,
    ).timeout(_kHttpWriteTimeout);
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    throw ApiException('Failed to delete vehicle: ${r.body}', statusCode: r.statusCode);
  }

  Future<void> postVehicleData({
    required String vehicleId,
    required double speed,
    required double rpm,
    double? fuelConsumption,
  }) async {
    final r = await _post(
      '/vehicle-data',
      body: {
        'vehicle_id': vehicleId,
        'speed': speed,
        'rpm': rpm.round(),
        'fuel_consumption': fuelConsumption ?? 0,
        'fuel_level': 50,
        'engine_temp': 90,
        'engine_load': 20,
        'throttle_position': 15,
        'error_codes': <String>[],
      },
    );
    await _jsonOrThrow(r);
  }

  Future<List<dynamic>> vehicleData(String vehicleId, {int limit = 100}) async {
    late final http.Response r;
    try {
      r = await _get('/vehicle-data/$vehicleId?limit=$limit');
    } on TimeoutException {
      throw ApiException('Request timed out — check network and API URL.', statusCode: null);
    }
    Object? raw;
    try {
      raw = r.body.isEmpty ? const <dynamic>[] : jsonDecode(r.body);
    } catch (_) {
      raw = const <dynamic>[];
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (raw is Map<String, dynamic> && raw['data'] != null) {
        final d = raw['data'];
        if (d is List<dynamic>) return d;
        if (d is List) return d;
        return const [];
      }
      return _decodeVehicleList(raw);
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> analyze(String vehicleId) async {
    final r = await _post('/analysis/generate/$vehicleId');
    return _jsonOrThrow(r);
  }

  Future<List<dynamic>> analysisHistory(String vehicleId) async {
    late final http.Response r;
    try {
      r = await _get('/analysis/vehicle/$vehicleId');
    } on TimeoutException {
      throw ApiException('Request timed out — check network and API URL.', statusCode: null);
    }
    Object? raw;
    try {
      raw = r.body.isEmpty ? const <dynamic>[] : jsonDecode(r.body);
    } catch (_) {
      raw = const <dynamic>[];
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return _decodeVehicleList(raw);
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> routeInsights({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
  }) async {
    final r = await _post(
      '/route/insights',
      body: {
        'dest_lat': destLat,
        'dest_lng': destLng,
        'origin_lat': ?originLat,
        'origin_lng': ?originLng,
      },
    );
    return _jsonOrThrow(r);
  }

  Future<void> shareRoute({
    required double oLat,
    required double oLng,
    required double dLat,
    required double dLng,
    String? label,
    String? departWindow,
  }) async {
    final r = await _post(
      '/routes/share',
      body: {
        'origin_lat': oLat,
        'origin_lng': oLng,
        'dest_lat': dLat,
        'dest_lng': dLng,
        'label': ?label,
        'depart_window': ?departWindow,
      },
    );
    await _jsonOrThrow(r);
  }

  Future<List<dynamic>> routeMatches({
    required double oLat,
    required double oLng,
    required double dLat,
    required double dLng,
  }) async {
    final q =
        'origin_lat=$oLat&origin_lng=$oLng&dest_lat=$dLat&dest_lng=$dLng&threshold_km=5';
    final r = await _get('/routes/matches?$q');
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<List<dynamic>> generateRecommendations(String vehicleId, {double? commuteKm}) async {
    var path = '/recommendations/generate?vehicle_id=$vehicleId';
    if (commuteKm != null) path += '&commute_km_estimate=$commuteKm';
    final r = await _post(path);
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<List<dynamic>> listRecommendations() async {
    final r = await _get('/recommendations/vehicle');
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  /// Server: `GET /recommendations/maintenance/:vehicleId`
  Future<List<dynamic>> maintenanceRecommendations(String vehicleId) async {
    final id = Uri.encodeComponent(vehicleId);
    late final http.Response r;
    try {
      r = await _get('/recommendations/maintenance/$id');
    } on TimeoutException {
      return const [];
    }
    Object? raw;
    try {
      raw = r.body.isEmpty ? const <dynamic>[] : jsonDecode(r.body);
    } catch (_) {
      return const [];
    }
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (raw is List<dynamic>) return raw;
      if (raw is List) return raw;
      return const [];
    }
    return const [];
  }
}
