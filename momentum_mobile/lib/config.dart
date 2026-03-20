import 'dart:io';

import 'package:flutter/foundation.dart';

/// Backend URL for the FastAPI server. Android emulator uses 10.0.2.2 to reach host machine.
String momentumApiBaseUrl() {
  if (kIsWeb) return 'http://127.0.0.1:8000';
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://127.0.0.1:8000';
}
