/// Place suggestion model from Nominatim geocoding.
library;

import 'package:flutter/material.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.displayName,
    required this.shortName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
  });

  final String placeId;
  final String displayName;
  final String shortName;
  final String address;
  final double lat;
  final double lng;
  final String category;

  IconData get icon {
    final c = category.toLowerCase();
    if (c.contains('university') || c.contains('school') || c.contains('college')) {
      return Icons.school_rounded;
    }
    if (c.contains('hospital') || c.contains('clinic') || c.contains('pharmacy')) {
      return Icons.local_hospital_rounded;
    }
    if (c.contains('restaurant') || c.contains('cafe') || c.contains('food')) {
      return Icons.restaurant_rounded;
    }
    if (c.contains('fuel') || c.contains('gas')) {
      return Icons.local_gas_station_rounded;
    }
    if (c.contains('hotel') || c.contains('guest')) {
      return Icons.hotel_rounded;
    }
    if (c.contains('airport')) return Icons.flight_rounded;
    if (c.contains('bus') || c.contains('station')) return Icons.directions_bus_rounded;
    if (c.contains('park') || c.contains('garden')) return Icons.park_rounded;
    if (c.contains('shop') || c.contains('mall') || c.contains('market')) {
      return Icons.shopping_bag_rounded;
    }
    if (c.contains('city') || c.contains('town') || c.contains('village')) {
      return Icons.location_city_rounded;
    }
    if (c.contains('highway') || c.contains('road') || c.contains('street')) {
      return Icons.add_road_rounded;
    }
    return Icons.location_on_rounded;
  }

  factory PlaceSuggestion.fromNominatim(Map<String, dynamic> m) {
    final address = m['address'] as Map<String, dynamic>? ?? {};

    // Build short name from address details
    final amenity = address['amenity']?.toString() ?? '';
    final name = m['name']?.toString() ?? '';
    final road = address['road']?.toString() ?? '';
    final shortName = amenity.isNotEmpty
        ? amenity
        : name.isNotEmpty
            ? name
            : road.isNotEmpty
                ? road
                : (m['display_name'] as String? ?? '').split(',').first.trim();

    // Build short address (city + country)
    final parts = <String>[];
    for (final key in ['suburb', 'city', 'county', 'state', 'country']) {
      final v = address[key]?.toString() ?? '';
      if (v.isNotEmpty) parts.add(v);
      if (parts.length >= 2) break;
    }
    final addressStr = parts.join(', ');

    final category = '${m['class'] ?? ''}/${m['type'] ?? ''}';

    return PlaceSuggestion(
      placeId: m['place_id']?.toString() ?? '',
      displayName: m['display_name'] as String? ?? shortName,
      shortName: shortName,
      address: addressStr,
      lat: double.tryParse(m['lat']?.toString() ?? '') ?? 0,
      lng: double.tryParse(m['lon']?.toString() ?? '') ?? 0,
      category: category,
    );
  }
}
