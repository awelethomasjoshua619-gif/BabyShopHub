import 'package:flutter/foundation.dart';

/// Server address WITHOUT /api.
/// Android emulator reaches your PC at 10.0.2.2. On a real phone run:
///   flutter run --dart-define=API_URL=http://YOUR_PC_IP:8081
String get apiOrigin {
  const override = String.fromEnvironment('API_URL');
  if (override.isNotEmpty) return override;
  if (kIsWeb) {
    final host = Uri.base.host;
    return 'http://${host.isNotEmpty ? host : 'localhost'}:8081';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8081';
  }
  return 'http://localhost:8081';
}

String get apiBaseUrl => '$apiOrigin/api';

/// Product images may be "/uploads/x.jpg" (relative) or a full URL.
String resolveImageUrl(String url) {
  if (url.startsWith('http')) return url;
  return '$apiOrigin${url.startsWith('/') ? '' : '/'}$url';
}
