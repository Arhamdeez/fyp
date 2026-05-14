/// OpenWeatherMap wrapper. Requires OWM_KEY dart-define.
/// Falls back gracefully when no key is provided.
library;

import 'dart:convert';

import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

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
    if (_owmKey.isEmpty) return WeatherInfo.unavailable();

    int attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final uri = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather'
          '?lat=$lat&lon=$lng&appid=$_owmKey&units=metric',
        );
        final res = await http.get(uri).timeout(_timeout);
        if (res.statusCode != 200) {
          developer.log('Weather API error: ${res.statusCode} ${res.body}', name: 'WeatherService');
          return WeatherInfo.unavailable();
        }

        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final weather = (m['weather'] as List<dynamic>).first
            as Map<String, dynamic>;
        final main = m['main'] as Map<String, dynamic>;
        final wind = m['wind'] as Map<String, dynamic>? ?? {};
        final rain = m['rain'] as Map<String, dynamic>? ?? {};

        return WeatherInfo(
          condition: weather['main'] as String? ?? 'Unknown',
          description: weather['description'] as String? ?? '',
          iconCode: weather['icon'] as String? ?? '01d',
          tempC: (main['temp'] as num?)?.toDouble() ?? 0,
          windKph: ((wind['speed'] as num?)?.toDouble() ?? 0) * 3.6,
          rainMmPerHour: (rain['1h'] as num?)?.toDouble() ?? 0,
        );
      } catch (e, st) {
        developer.log('Weather API exception attempt $attempts: $e', name: 'WeatherService', error: e, stackTrace: st);
        if (attempts >= 2) break;
        await Future.delayed(const Duration(seconds: 1)); // simple backoff
      }
    }
    return WeatherInfo.unavailable();
  }
}
