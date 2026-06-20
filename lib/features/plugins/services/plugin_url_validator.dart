class PluginUrlValidator {
  static const invalidUrlMessage = 'URL không hợp lệ';

  static const _forbiddenSchemes = {
    'file',
    'javascript',
    'data',
    'ftp',
    'about',
    'chrome',
  };

  /// Returns `null` when [rawUrl] is valid, otherwise an error message.
  String? validate(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return invalidUrlMessage;

    final lower = trimmed.toLowerCase();
    for (final scheme in _forbiddenSchemes) {
      if (lower.startsWith('$scheme:')) return invalidUrlMessage;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return invalidUrlMessage;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return invalidUrlMessage;
    }
    if (_forbiddenSchemes.contains(scheme)) {
      return invalidUrlMessage;
    }

    return null;
  }
}
