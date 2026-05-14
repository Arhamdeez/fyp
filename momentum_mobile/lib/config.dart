import 'dart:io';

import 'package:flutter/foundation.dart';

/// Base URL for the REST API (must include `/api` for the Node MERN server).
///
/// **Physical phone + laptop on same Wi‑Fi:** Bluetooth goes phone↔OBD only; HTTP goes
/// phone↔your PC. Set your machine's LAN IP (e.g. `192.168.1.42`):
///
/// ```bash
/// flutter run --dart-define=MOMENTUM_API_BASE=http://192.168.1.42:5001/api
/// ```
///
/// **Android emulator on the same machine as the server:** `10.0.2.2` is the host PC.
String momentumApiBaseUrl() {
  const fromEnv = String.fromEnvironment(
    'MOMENTUM_API_BASE',
    defaultValue: '',
  );
  if (fromEnv.isNotEmpty) {
    // Remove all whitespace so typos like "http:// 192.168..." still work.
    var base = fromEnv.trim().replaceAll(RegExp(r'\s+'), '');
    if (!base.endsWith('/api')) {
      base = base.endsWith('/') ? '${base}api' : '$base/api';
    }
    return base.replaceAll(RegExp(r'/+$'), '');
  }

  const defaultPort = 5001;
  if (kIsWeb) return 'http://127.0.0.1:$defaultPort/api';

  if (!kIsWeb && Platform.isAndroid) {
    // Emulator: special alias for host loopback.
    return 'http://10.0.2.2:$defaultPort/api';
  }

  // iOS Simulator / desktop: server on same machine.
  return 'http://127.0.0.1:$defaultPort/api';
}

/// Google Weather API key — enable **Weather API** on the GCP project.
///
/// Compile-time defines (restart app after changing):
/// ```bash
/// flutter run --dart-define=GOOGLE_WEATHER_KEY=your_key
/// # or:
/// flutter run --dart-define=WEATHER_API_KEY=your_key
/// ```
String googleWeatherApiKey() {
  const primary =
      String.fromEnvironment('GOOGLE_WEATHER_KEY', defaultValue: '');
  if (primary.trim().isNotEmpty) return primary.trim();
  const alt = String.fromEnvironment('WEATHER_API_KEY', defaultValue: '');
  return alt.trim();
}
