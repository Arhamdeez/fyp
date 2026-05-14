/// Opens Google Maps directions using coordinates when available.
library;

import 'package:url_launcher/url_launcher.dart';

import '../models/route_model.dart';

abstract final class MapsLauncher {
  MapsLauncher._();

  /// Builds a directions URL that differs per [mapsVariant]:
  /// - **Eco**: avoid highways (`dirflg=h`) where Maps honours it.
  /// - **Least traffic**: avoid tolls (`dirflg=t`) as an alternate corridor hint.
  /// - **Recommended**: adds a light midpoint waypoint so the path differs from “fastest”.
  /// - **Fastest**: straight OD directions.
  static Uri directionsUri({
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    required String originLabel,
    required String destLabel,
    RouteType? mapsVariant,
  }) {
    final params = <String, String>{
      'api': '1',
      'travelmode': 'driving',
    };

    final olat = originLat;
    final olng = originLng;
    final dlat = destLat;
    final dlng = destLng;

    if (olat != null && olng != null && dlat != null && dlng != null) {
      params['origin'] = '$olat,$olng';
      params['destination'] = '$dlat,$dlng';

      if (mapsVariant == RouteType.recommended) {
        final midLat = (olat + dlat) / 2 + 0.0025;
        final midLng = (olng + dlng) / 2 + 0.0025;
        params['waypoints'] =
            '${midLat.toStringAsFixed(5)},${midLng.toStringAsFixed(5)}';
      }
    } else {
      params['origin'] = originLabel;
      params['destination'] = destLabel;
    }

    switch (mapsVariant) {
      case RouteType.eco:
        params['dirflg'] = 'h';
        break;
      case RouteType.leastTraffic:
        params['dirflg'] = 't';
        break;
      case RouteType.fastest:
      case RouteType.recommended:
      case null:
        break;
    }

    return Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/dir/',
      queryParameters: params,
    );
  }

  static Future<bool> openDirections({
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    required String originLabel,
    required String destLabel,
    RouteType? mapsVariant,
  }) async {
    final uri = directionsUri(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      originLabel: originLabel,
      destLabel: destLabel,
      mapsVariant: mapsVariant,
    );

    try {
      var launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      return launched;
    } catch (_) {
      return false;
    }
  }
}
