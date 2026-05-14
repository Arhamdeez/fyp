/// Nominatim geocoding service — free, no API key required.
/// Rate limit: 1 req/sec. Debouncing is handled in the widget.
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/place_suggestion.dart';

class PlacesService {
  PlacesService._();
  static final PlacesService instance = PlacesService._();

  static const _base = 'https://nominatim.openstreetmap.org';
  static const _ua = 'MomentumApp/1.0 (momentum.fyp.app)';
  static const _timeout = Duration(seconds: 15);

  // Simple in-memory cache to avoid redundant requests
  final _cache = <String, List<PlaceSuggestion>>{};

  /// Search places by query string. Returns up to 8 suggestions.
  Future<List<PlaceSuggestion>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final key = q.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;

    int attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final uri = Uri.parse('$_base/search').replace(
          queryParameters: {
            'q': q,
            'format': 'json',
            'limit': '8',
            'addressdetails': '1',
            'accept-language': 'en',
            // Bias results towards Pakistan where the app is used
            'countrycodes': 'pk',
          },
        );

        final res = await http
            .get(uri, headers: {'User-Agent': _ua})
            .timeout(_timeout);

        if (res.statusCode != 200) {
          developer.log('Places API error: ${res.statusCode} ${res.body}', name: 'PlacesService');
          return const [];
        }

        final list = jsonDecode(res.body) as List<dynamic>;
        final results = list
            .map((m) => PlaceSuggestion.fromNominatim(m as Map<String, dynamic>))
            .where((s) => s.lat != 0 && s.lng != 0)
            .toList();

        _cache[key] = results;
        // Evict old entries when cache grows large
        if (_cache.length > 80) {
          _cache.remove(_cache.keys.first);
        }
        return results;
      } catch (e, st) {
        developer.log('Places API exception attempt $attempts: $e', name: 'PlacesService', error: e, stackTrace: st);
        if (attempts >= 2) break;
        await Future.delayed(const Duration(seconds: 1)); // simple backoff
      }
    }
    return const [];
  }

  /// Convert GPS coordinates to a human-readable place name.
  Future<String> reverseGeocode(double lat, double lng) async {
    int attempts = 0;
    while (attempts < 2) {
      attempts++;
      try {
        final uri = Uri.parse('$_base/reverse').replace(
          queryParameters: {
            'lat': lat.toString(),
            'lon': lng.toString(),
            'format': 'json',
            'zoom': '16',
            'accept-language': 'en',
          },
        );

        final res = await http
            .get(uri, headers: {'User-Agent': _ua})
            .timeout(_timeout);

        if (res.statusCode != 200) {
          developer.log('Places reverse geocode error: ${res.statusCode} ${res.body}', name: 'PlacesService');
          return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        }

        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final display = m['display_name'] as String? ?? '';
        if (display.isEmpty) {
          return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
        }
        // Return first 2 meaningful parts for a concise label
        final parts = display.split(',');
        if (parts.length >= 2) {
          return '${parts[0].trim()}, ${parts[1].trim()}';
        }
        return parts.first.trim();
      } catch (e, st) {
        developer.log('Places reverse geocode exception attempt $attempts: $e', name: 'PlacesService', error: e, stackTrace: st);
        if (attempts >= 2) break;
        await Future.delayed(const Duration(seconds: 1)); // simple backoff
      }
    }
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}
