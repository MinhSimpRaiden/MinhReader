import '../models/plugin_manifest.dart';

class PluginValidationException implements Exception {
  const PluginValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PluginValidator {
  static const _forbiddenKeys = {
    'script',
    'javascript',
    'eval',
    'executable',
    'dartCode',
    'jsCode',
    'cookie',
    'authorization',
    'token',
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
    if (manifest.license.trim().isEmpty) {
      throw const PluginValidationException('Plugin thiếu giấy phép');
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
        if (_forbiddenKeys.contains('${entry.key}'.toLowerCase())) {
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
