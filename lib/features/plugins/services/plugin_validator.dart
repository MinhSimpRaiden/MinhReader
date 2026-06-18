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
    _rejectExecutableKeys(json);
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
    if (manifest.sourceType == 'static_json' && manifest.stories.isEmpty) {
      throw const PluginValidationException('Plugin không có dữ liệu truyện');
    }
  }

  void _rejectExecutableKeys(dynamic value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = '${entry.key}'.toLowerCase();
        if (_forbiddenExecutableKeys.contains(key) ||
            _forbiddenSecretKeys.any((forbidden) => key.contains(forbidden))) {
          throw const PluginValidationException(
            'Plugin không chạy mã thực thi',
          );
        }
        _rejectExecutableKeys(entry.value);
      }
    } else if (value is List) {
      for (final item in value) {
        _rejectExecutableKeys(item);
      }
    }
  }
}
