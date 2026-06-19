import '../models/plugin_manifest.dart';

class PluginValidationException implements Exception {
  const PluginValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PluginValidator {
  static const _forbiddenExecutableKeys = {
    'script',
    'javascript',
    'eval',
    'executable',
    'code',
    'dartcode',
    'jscode',
  };

  static const _forbiddenSecretKeys = {
    'cookie',
    'authorization',
    'token',
    'authtoken',
  };

  void validateRaw(Map<String, dynamic> json) {
    _rejectDangerousKeys(json);
    validate(PluginManifest.fromJson(json));
  }

  void validate(PluginManifest manifest) {
    if (manifest.id.trim().isEmpty ||
        manifest.name.trim().isEmpty ||
        manifest.version.trim().isEmpty) {
      throw const PluginValidationException('Plugin không hợp lệ');
    }
    if (!{'text', 'comic', 'mixed'}.contains(manifest.contentType)) {
      throw const PluginValidationException('Plugin không hợp lệ');
    }
    if (!{'static_json', 'api_json'}.contains(manifest.sourceType)) {
      throw const PluginValidationException('Plugin không hợp lệ');
    }
    _validateHeaders(manifest);
    _validateApiJson(manifest);
    if (manifest.sourceType == 'static_json' && manifest.stories.isEmpty) {
      throw const PluginValidationException('Plugin không có dữ liệu truyện');
    }
  }

  void _validateHeaders(PluginManifest manifest) {
    for (final key in manifest.headers.keys) {
      final lower = key.toLowerCase();
      if (lower.contains('authorization') ||
          lower.contains('cookie') ||
          lower.contains('token')) {
        throw const PluginValidationException(
          'Plugin không được hardcode token/cookie',
        );
      }
    }
  }

  void _validateApiJson(PluginManifest manifest) {
    if (manifest.sourceType != 'api_json') return;
    final baseUrl = manifest.baseUrl?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const PluginValidationException('Plugin api_json cần baseUrl');
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw const PluginValidationException('baseUrl chỉ được dùng http/https');
    }
    for (final endpoint in manifest.endpoints.values) {
      _rejectDangerousEndpoint(endpoint);
    }
    if (manifest.features.catalog && _endpoint(manifest, 'catalog').isEmpty) {
      throw const PluginValidationException('Plugin thiếu endpoint catalog');
    }
    if (manifest.features.detail && _endpoint(manifest, 'detail').isEmpty) {
      throw const PluginValidationException('Plugin thiếu endpoint detail');
    }
    if (manifest.features.chapters && _endpoint(manifest, 'chapters').isEmpty) {
      throw const PluginValidationException('Plugin thiếu endpoint chapters');
    }
    if (manifest.features.readText &&
        _endpoint(manifest, 'chapterContent').isEmpty) {
      throw const PluginValidationException(
        'Plugin thiếu endpoint chapterContent',
      );
    }
    if (manifest.features.readComic &&
        _endpoint(manifest, 'chapterImages').isEmpty) {
      throw const PluginValidationException(
        'Plugin thiếu endpoint chapterImages',
      );
    }
  }

  String _endpoint(PluginManifest manifest, String key) =>
      manifest.endpoints[key]?.trim() ?? '';

  void _rejectDangerousEndpoint(String endpoint) {
    final lower = endpoint.toLowerCase();
    if (lower.contains('script') ||
        lower.contains('javascript') ||
        lower.contains('eval') ||
        lower.contains('executable')) {
      throw const PluginValidationException('Endpoint plugin không an toàn');
    }
  }

  void _rejectDangerousKeys(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}'.toLowerCase();
        if (_forbiddenExecutableKeys.contains(key) ||
            _forbiddenSecretKeys.any((forbidden) => key.contains(forbidden))) {
          throw const PluginValidationException(
            'Plugin không chạy mã thực thi',
          );
        }
        _rejectDangerousKeys(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        _rejectDangerousKeys(item);
      }
    }
  }
}
