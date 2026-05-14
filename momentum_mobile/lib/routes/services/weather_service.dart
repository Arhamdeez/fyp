/// Weather via Google Weather API (preferred) or OpenWeatherMap (fallback).
///
/// Keys at build/run time:
/// - `--dart-define=GOOGLE_WEATHER_KEY=` or `--dart-define=WEATHER_API_KEY=`
/// - `--dart-define=OWM_KEY=` (OpenWeatherMap fallback)
library;

import 'dart:convert';

import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../models/route_model.dart';

const String _owmKey = String.fromEnvironment('OWM_KEY', defaultValue: '');
const Duration _timeout = Duration(seconds: 15);

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  Future<WeatherInfo> fetchWeather({
    required double lat,
    required double lng,
  }) async {
    final googleKey = googleWeatherApiKey();
    if (googleKey.isNotEmpty) {
      final g = await _fetchGoogleCurrent(lat, lng, googleKey);
      if (g != null) return g;
    }
    if (_owmKey.isNotEmpty) {
      final o = await _fetchOpenWeatherMap(lat, lng);
      if (o != null) return o;
    }
    return WeatherInfo.unavailable();
  }

  Future<WeatherInfo?> _fetchGoogleCurrent(
    double lat,
    double lng,
    String apiKey,
  ) async {
    var attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final uri =
            Uri.https('weather.googleapis.com', '/v1/currentConditions:lookup', {
          'key': apiKey,
          'location.latitude': lat.toString(),
          'location.longitude': lng.toString(),
          'unitsSystem': 'METRIC',
        });
        final res = await http.get(uri).timeout(_timeout);
        if (res.statusCode != 200) {
          developer.log(
            'Google Weather error: ${res.statusCode} ${res.body}',
            name: 'WeatherService',
          );
          return null;
        }

        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final parsed = _parseGoogleCurrent(m);
        if (parsed == null) {
          developer.log(
            'Google Weather: unexpected JSON shape',
            name: 'WeatherService',
          );
        }
        return parsed;
      } catch (e, st) {
        developer.log(
          'Google Weather exception attempt $attempts: $e',
          name: 'WeatherService',
          error: e,
          stackTrace: st,
        );
        if (attempts >= 2) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  WeatherInfo? _parseGoogleCurrent(Map<String, dynamic> m) {
    try {
      final wc = m['weatherCondition'] as Map<String, dynamic>? ?? {};
      final descMap = wc['description'] as Map<String, dynamic>? ?? {};
      final descriptionText = (descMap['text'] as String?) ?? '';
      final type = (wc['type'] as String?) ?? 'Unknown';
      final condition = descriptionText.isNotEmpty
          ? descriptionText
          : type.replaceAll('_', ' ');

      final iconUri = (wc['iconBaseUri'] as String?) ?? '';
      final iconTail = iconUri.split('/').last;
      final iconCode =
          iconTail.isNotEmpty ? iconTail : type.toLowerCase();

      final tempMap = m['temperature'] as Map<String, dynamic>? ?? {};
      var tempC = (tempMap['degrees'] as num?)?.toDouble() ?? 0.0;
      final tempUnit = tempMap['unit'] as String?;
      if (tempUnit == 'FAHRENHEIT') {
        tempC = (tempC - 32) * 5 / 9;
      }

      final windMap = m['wind'] as Map<String, dynamic>? ?? {};
      final speedMap = windMap['speed'] as Map<String, dynamic>? ?? {};
      var windKph = (speedMap['value'] as num?)?.toDouble() ?? 0.0;
      final windUnit = speedMap['unit'] as String?;
      if (windUnit == 'MILES_PER_HOUR') {
        windKph *= 1.60934;
      }

      final precip = m['precipitation'] as Map<String, dynamic>? ?? {};
      final qpf = precip['qpf'] as Map<String, dynamic>? ?? {};
      var rainMmPerHour = (qpf['quantity'] as num?)?.toDouble() ?? 0.0;
      final qpfUnit = qpf['unit'] as String?;
      if (qpfUnit == 'INCHES') {
        rainMmPerHour *= 25.4;
      }
      final probMap = precip['probability'] as Map<String, dynamic>? ?? {};
      final pct = (probMap['percent'] as num?)?.toDouble() ?? 0;
      final pType = (probMap['type'] as String?) ?? '';
      if (rainMmPerHour <= 0 &&
          pct > 35 &&
          pType.toUpperCase().contains('RAIN')) {
        rainMmPerHour = 0.4;
      }

      return WeatherInfo(
        condition: condition,
        tempC: tempC,
        windKph: windKph,
        rainMmPerHour: rainMmPerHour,
        iconCode: iconCode,
        description: descriptionText.isNotEmpty ? descriptionText : condition,
      );
    } catch (e, st) {
      developer.log(
        'Google Weather JSON parse failed: $e',
        name: 'WeatherService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<WeatherInfo?> _fetchOpenWeatherMap(double lat, double lng) async {
    var attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final uri = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather'
          '?lat=$lat&lon=$lng&appid=$_owmKey&units=metric',
        );
        final res = await http.get(uri).timeout(_timeout);
        if (res.statusCode != 200) {
          developer.log(
            'OpenWeatherMap error: ${res.statusCode} ${res.body}',
            name: 'WeatherService',
          );
          return null;
        }

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final weather = (body['weather'] as List<dynamic>).first
            as Map<String, dynamic>;
        final main = body['main'] as Map<String, dynamic>;
        final wind = body['wind'] as Map<String, dynamic>? ?? {};
        final rain = body['rain'] as Map<String, dynamic>? ?? {};

        return WeatherInfo(
          condition: weather['main'] as String? ?? 'Unknown',
          description: weather['description'] as String? ?? '',
          iconCode: weather['icon'] as String? ?? '01d',
          tempC: (main['temp'] as num?)?.toDouble() ?? 0,
          windKph: ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
          rainMmPerHour: (rain['1h'] as num?)?.toDouble() ?? 0,
        );
      } catch (e, st) {
        developer.log(
          'OpenWeatherMap exception attempt $attempts: $e',
          name: 'WeatherService',
          error: e,
          stackTrace: st,
        );
        if (attempts >= 2) break;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }
}
