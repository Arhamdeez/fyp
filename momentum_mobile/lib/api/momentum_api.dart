import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class MomentumApi {
  MomentumApi({String? baseUrl}) : baseUrl = baseUrl ?? momentumApiBaseUrl();

  final String baseUrl;
  String? bearerToken;

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
      msg = m['detail']?.toString() ?? r.body;
    } catch (_) {}
    throw ApiException(msg, statusCode: r.statusCode);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    await _jsonOrThrow(r);
  }

  Future<String> login({required String email, required String password}) async {
    final r = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final m = await _jsonOrThrow(r);
    return m['access_token'] as String;
  }

  Future<List<dynamic>> vehicles() async {
    final r = await http.get(Uri.parse('$baseUrl/vehicles'), headers: _headers);
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> createVehicle({
    required String model,
    required String type,
    int? year,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/vehicles'),
      headers: _headers,
      body: jsonEncode({
        'vehicle_model': model,
        'vehicle_type': type,
        'year': ?year,
      }),
    );
    return _jsonOrThrow(r);
  }

  Future<void> postVehicleData({
    required int vehicleId,
    required double speed,
    required double rpm,
    double? fuelConsumption,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/vehicles/$vehicleId/data'),
      headers: _headers,
      body: jsonEncode({
        'speed': speed,
        'rpm': rpm,
        'fuel_consumption': ?fuelConsumption,
      }),
    );
    await _jsonOrThrow(r);
  }

  Future<List<dynamic>> vehicleData(int vehicleId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleId/data?limit=100'),
      headers: _headers,
    );
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> analyze(int vehicleId) async {
    final r = await http.post(
      Uri.parse('$baseUrl/vehicles/$vehicleId/analyze'),
      headers: _headers,
    );
    return _jsonOrThrow(r);
  }

  Future<List<dynamic>> analysisHistory(int vehicleId) async {
    final r = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleId/analysis'),
      headers: _headers,
    );
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<Map<String, dynamic>> routeInsights({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
  }) async {
    final r = await http.post(
      Uri.parse('$baseUrl/route/insights'),
      headers: _headers,
      body: jsonEncode({
        'dest_lat': destLat,
        'dest_lng': destLng,
        'origin_lat': ?originLat,
        'origin_lng': ?originLng,
      }),
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
    final r = await http.post(
      Uri.parse('$baseUrl/routes/share'),
      headers: _headers,
      body: jsonEncode({
        'origin_lat': oLat,
        'origin_lng': oLng,
        'dest_lat': dLat,
        'dest_lng': dLng,
        'label': ?label,
        'depart_window': ?departWindow,
      }),
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
    final r = await http.get(Uri.parse('$baseUrl/routes/matches?$q'), headers: _headers);
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<List<dynamic>> generateRecommendations(int vehicleId, {double? commuteKm}) async {
    var url = '$baseUrl/recommendations/generate?vehicle_id=$vehicleId';
    if (commuteKm != null) url += '&commute_km_estimate=$commuteKm';
    final r = await http.post(Uri.parse(url), headers: _headers);
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }

  Future<List<dynamic>> listRecommendations() async {
    final r = await http.get(Uri.parse('$baseUrl/recommendations'), headers: _headers);
    final raw = jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return raw as List<dynamic>;
    }
    throw ApiException(raw.toString(), statusCode: r.statusCode);
  }
}
