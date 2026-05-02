import 'package:flutter/foundation.dart';

/// Shared live OBD readings from [ObdTab]; Home/Vehicle listen to prefer real dongle data over demo.
class ObdLiveStore extends ChangeNotifier {
  ObdLiveStore._();
  static final ObdLiveStore instance = ObdLiveStore._();

  bool elmConnected = false;
  /// Set when a link is up (e.g. `"OBDII · 00:11:22:33:44:55"`).
  String? adapterLabel;
  int? speedKph;
  double? rpm;
  DateTime? lastUpdate;

  /// [adapterLabel] only overwrites when non-null (so poll heartbeats do not clear the name).
  void updateFromObd({
    required bool connected,
    int? speed,
    double? rpm,
    String? adapterLabel,
  }) {
    elmConnected = connected;
    if (!connected) {
      speedKph = null;
      this.rpm = null;
      lastUpdate = null;
      this.adapterLabel = null;
      notifyListeners();
      return;
    }
    if (adapterLabel != null) {
      this.adapterLabel = adapterLabel;
    }
    if (speed != null) speedKph = speed;
    if (rpm != null) this.rpm = rpm;
    lastUpdate = DateTime.now();
    notifyListeners();
  }
}
