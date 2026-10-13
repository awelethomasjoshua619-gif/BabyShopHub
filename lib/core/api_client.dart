import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'http_factory.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// One place that talks HTTP: adds the login, turns errors into readable text.
class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 15);

  final http.Client _client = createClient();

  /// Holds the real backend's JSESSIONID cookie on native platforms.
  String? _token;
  String? get token => _token;

  /// Called when the server rejects our login (expired / invalid).
  void Function()? onUnauthorized;

  /// True while Session probes for the admin role (a 403 there is expected).
  bool suppressExpiry = false;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> setToken(String? token, {bool persist = true}) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null && persist) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (_token != null) {
      if (!kIsWeb) {
        h['Cookie'] = _token!; // phones send the saved session cookie
      }
      // In a browser the cookie is sent automatically.
    }
    return h;
  }

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
    '$apiBaseUrl$path',
  ).replace(queryParameters: query == null || query.isEmpty ? null : query);

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send(() => _client.get(_uri(path, query), headers: _headers()));
  }

  Future<dynamic> post(String path, [Object? body]) {
    return _send(
      () => _client.post(
        _uri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<dynamic> put(String path, Object body) {
    return _send(
      () =>
          _client.put(_uri(path), headers: _headers(), body: jsonEncode(body)),
    );
  }

  Future<dynamic> patch(String path, Object body) {
    return _send(
      () => _client.patch(
        _uri(path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
    );
  }

  Future<dynamic> delete(String path) {
    return _send(() => _client.delete(_uri(path), headers: _headers()));
  }

  /// Admin "create product": a JSON part named `product`, plain form fields
  /// and an optional picture.
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, String>? query,
    required String partName,
    required Map<String, dynamic> partJson,
    Uint8List? fileBytes,
    String? fileName,
  }) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path, query))
        ..headers.addAll(_headers(json: false))
        ..fields.addAll(fields)
        ..files.add(
          http.MultipartFile.fromString(
            partName,
            jsonEncode(partJson),
            filename: '$partName.json',
            contentType: MediaType('application', 'json'),
          ),
        );
      if (fileBytes != null) {
        request.files.add(_imagePart(fileBytes, fileName));
      }
      return http.Response.fromStream(await _client.send(request));
    });
  }

  /// Uploads one picture, e.g. to replace a product's image.
  Future<dynamic> uploadFile(
    String path, {
    required Uint8List bytes,
    required String fileName,
    String fieldName = 'image',
  }) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers(json: false))
        ..files.add(_imagePart(bytes, fileName, fieldName: fieldName));
      return http.Response.fromStream(await _client.send(request));
    });
  }

  http.MultipartFile _imagePart(
    Uint8List bytes,
    String? name, {
    String fieldName = 'image',
  }) {
    final isPng = bytes.length > 3 && bytes[0] == 0x89 && bytes[1] == 0x50;
    return http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: name ?? (isPng ? 'image.png' : 'image.jpg'),
      contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
    );
  }

  /// Real backend login: it answers 204 and sets a JSESSIONID cookie.
  Future<String> loginSession(String path, Object body) async {
    final http.Response res;
    try {
      res = await _client
          .post(_uri(path), headers: _headers(), body: jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.');
    } catch (_) {
      throw ApiException(
        "Can't reach the server. Check your connection and that the backend is running.",
      );
    }
    // The backend uses 202 when the password is correct but the account still
    // needs email verification. This is not a completed login and has no cookie.
    if (res.statusCode == 202) {
      final message = utf8.decode(res.bodyBytes).trim();
      throw ApiException(
        message.isEmpty
            ? 'Please verify your email before logging in.'
            : message,
        res.statusCode,
      );
    }
    _handle(res); // throws a readable error when the login failed
    if (kIsWeb) return 'browser-session'; // the browser keeps the cookie
    final cookie = RegExp(
      r'JSESSIONID=[^;,\s]+',
    ).firstMatch(res.headers['set-cookie'] ?? '')?.group(0);
    if (cookie == null) {
      throw ApiException('Login worked but the server sent no session.');
    }
    return cookie;
  }

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(_timeout);
      return _handle(res);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Try again.');
    } catch (_) {
      throw ApiException(
        "Can't reach the server. Check your connection and that the backend is running.",
      );
    }
  }

  dynamic _handle(http.Response res) {
    final body = utf8.decode(res.bodyBytes).trim();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body.isEmpty) return null;
      try {
        return jsonDecode(body);
      } catch (_) {
        return body; // plain-text answers such as "Email verified..."
      }
    }

    var message = '';
    if (body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          message = (decoded['error'] ?? decoded['message'] ?? '').toString();
        }
      } catch (_) {
        message = body;
      }
    }
    final expired =
        res.statusCode == 401 || (res.statusCode == 403 && !suppressExpiry);
    if (expired && _token != null) {
      onUnauthorized?.call();
      message = 'Your session expired. Please log in again.';
    } else if (message.isEmpty) {
      message = switch (res.statusCode) {
        401 => 'Please log in to continue.',
        403 => 'You are not allowed to do that.',
        404 => 'We could not find what you asked for.',
        >= 500 => 'Something went wrong on the server. Try again later.',
        _ => 'Request failed (${res.statusCode}).',
      };
    }
    throw ApiException(message, res.statusCode);
  }
}
