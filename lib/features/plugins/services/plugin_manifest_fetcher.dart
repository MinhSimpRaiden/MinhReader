import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class PluginManifestFetchException implements Exception {
  const PluginManifestFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PluginManifestFetcher {
  PluginManifestFetcher({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.maxBytes = 2 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  static const fetchFailedMessage = 'Không thể tải plugin từ URL';
  static const invalidJsonMessage =
      'Nội dung tải về không phải JSON hợp lệ';

  final http.Client _client;
  final Duration timeout;
  final int maxBytes;

  Future<Map<String, dynamic>> fetchManifestJson(String url) async {
    final uri = Uri.parse(url.trim());
    late http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const PluginManifestFetchException(fetchFailedMessage);
    } catch (_) {
      throw const PluginManifestFetchException(fetchFailedMessage);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const PluginManifestFetchException(fetchFailedMessage);
    }

    final bodyBytes = response.bodyBytes;
    if (bodyBytes.length > maxBytes) {
      throw const PluginManifestFetchException(fetchFailedMessage);
    }

    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
      throw const FormatException();
    } catch (_) {
      throw const PluginManifestFetchException(invalidJsonMessage);
    }
  }
}
