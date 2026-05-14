/// Distinct accent colours per route variant (cards + detail sheet).
library;

import 'package:flutter/material.dart';

import 'models/route_model.dart';

extension RouteTypeAccent on RouteType {
  Color get accentColor => switch (this) {
        RouteType.fastest => const Color(0xFF2563EB),
        RouteType.eco => const Color(0xFF16A34A),
        RouteType.leastTraffic => const Color(0xFFF59E0B),
        RouteType.recommended => const Color(0xFF0D9488),
      };
}
