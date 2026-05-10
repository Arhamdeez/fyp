import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationStore extends ChangeNotifier {
  LocationStore._();
  static final LocationStore instance = LocationStore._();

  Position? position;
  String? error;
  bool loading = false;

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Location services are off');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw StateError('Location permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError('Location permission permanently denied (open settings)');
      }

      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}

