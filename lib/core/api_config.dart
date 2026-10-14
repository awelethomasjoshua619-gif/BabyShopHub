import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const _backendPort = 8081;
const _override = String.fromEnvironment('API_URL');

String? _resolved;

String get apiOrigin {
  if (_override.isNotEmpty) return _override;
  if (_resolved != null) return _resolved!;
  if (kIsWeb) {
    final host = Uri.base.host;
    return 'http://${host.isNotEmpty ? host : 'localhost'}:$_backendPort';
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:$_backendPort';
  }
  return 'http://localhost:$_backendPort';
}

/// Call once in main() before runApp. On Android it tries each likely
/// address one by one and keeps the first that answers.
Future<void> resolveApiOrigin() async {
  if (_override.isNotEmpty || kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;

  const candidates = [
    'http://localhost:$_backendPort', // real phone via `adb reverse`
    'http://10.0.2.2:$_backendPort', // Android emulator
  ];
  for (final origin in candidates) {
    if (await _reachable(origin)) {
      _resolved = origin;
      debugPrint('API origin: $origin');
      return;
    }
  }
  debugPrint('API origin: no backend answered, using $apiOrigin');
}

Future<bool> _reachable(String origin) async {
  try {
    // Any HTTP answer (even 401/404) proves the server is there.
    await http
        .get(Uri.parse('$origin/api/categories'))
        .timeout(const Duration(milliseconds: 1500));
    return true;
  } catch (_) {
    return false;
  }
}

String get apiBaseUrl => '$apiOrigin/api';

/// Product images may be "/uploads/x.jpg" (relative) or a full URL.
String resolveImageUrl(String url) {
  if (url.startsWith('http')) return url;
  return '$apiOrigin${url.startsWith('/') ? '' : '/'}$url';
}
