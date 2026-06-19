import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/plugin_manifest.dart';
import 'plugin_validator.dart';

class PluginHttpException implements Exception {
  const PluginHttpException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PluginHttpClient {
  PluginHttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  Uri buildUrl(
    PluginManifest manifest,
    String endpointTemplate, {
    int? page,
    int? limit,
    String? query,
    String? storyId,
    String? chapterId,
  }) {
    final baseUrl = manifest.baseUrl?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const PluginHttpException('Plugin thiếu baseUrl');
    }
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null ||
        !(baseUri.scheme == 'http' || baseUri.scheme == 'https')) {
      throw const PluginHttpException('baseUrl chỉ được dùng http/https');
    }

    final replacements = <String, String>{};
    if (page != null) replacements['page'] = '$page';
    if (limit != null) replacements['limit'] = '$limit';
    if (query != null) replacements['query'] = query;
    if (storyId != null) replacements['storyId'] = storyId;
    if (chapterId != null) replacements['chapterId'] = chapterId;

    var endpoint = endpointTemplate.trim();
    for (final entry in replacements.entries) {
      endpoint = endpoint.replaceAll(
        '{${entry.key}}',
        Uri.encodeComponent(entry.value),
      );
    }

    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    final uri = Uri.parse('$normalizedBase/$normalizedEndpoint');
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const PluginHttpException('Endpoint chỉ được dùng http/https');
    }
    return uri;
  }

  Future<Map<String, dynamic>> getJson(
    PluginManifest manifest,
    String endpointTemplate, {
    int? page,
    int? limit,
    String? query,
    String? storyId,
    String? chapterId,
  }) async {
    final uri = buildUrl(
      manifest,
      endpointTemplate,
      page: page,
      limit: limit,
      query: query,
      storyId: storyId,
      chapterId: chapterId,
    );
    final headers = _safeHeaders(manifest);
    late http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(timeout);
    } on TimeoutException {
      throw const PluginHttpException('Kết nối plugin quá thời gian chờ');
    } catch (error) {
      throw PluginHttpException('Không thể gọi endpoint plugin: $error');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PluginHttpException(
        'Endpoint plugin trả về lỗi ${response.statusCode}',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry('$key', value));
      }
      throw const FormatException();
    } catch (_) {
      throw const PluginHttpException('JSON plugin không hợp lệ');
    }
  }

  Map<String, String> _safeHeaders(PluginManifest manifest) {
    final headers = <String, String>{};
    for (final entry in manifest.headers.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('cookie') ||
          key.contains('authorization') ||
          key.contains('token')) {
        throw const PluginValidationException(
          'Plugin không được hardcode token/cookie',
        );
      }
      headers[entry.key] = entry.value;
    }
    headers.putIfAbsent('accept', () => 'application/json');
    return headers;
  }
}
