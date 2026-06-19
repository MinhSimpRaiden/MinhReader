class PluginComicImageSafety {
  const PluginComicImageSafety._();

  static bool isSupportedImageUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.host.trim().isNotEmpty &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  static List<String> normalizeImageUrls(Iterable<String> values) {
    return [
      for (final value in values)
        if (value.trim().isNotEmpty) value.trim(),
    ];
  }
}
