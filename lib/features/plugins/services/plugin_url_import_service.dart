import '../models/plugin_manifest.dart';
import 'plugin_manifest_fetcher.dart';
import 'plugin_url_validator.dart';
import 'plugin_validator.dart';

class PluginUrlImportException implements Exception {
  const PluginUrlImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PluginUrlImportResult {
  const PluginUrlImportResult({
    required this.manifest,
    required this.sourceUrl,
  });

  final PluginManifest manifest;
  final String sourceUrl;
}

class PluginUrlImportService {
  PluginUrlImportService({
    PluginUrlValidator? urlValidator,
    PluginManifestFetcher? fetcher,
    PluginValidator? manifestValidator,
  }) : _urlValidator = urlValidator ?? PluginUrlValidator(),
       _fetcher = fetcher ?? PluginManifestFetcher(),
       _manifestValidator = manifestValidator ?? PluginValidator();

  final PluginUrlValidator _urlValidator;
  final PluginManifestFetcher _fetcher;
  final PluginValidator _manifestValidator;

  Future<PluginUrlImportResult> fetchAndValidate(String rawUrl) async {
    final urlError = _urlValidator.validate(rawUrl);
    if (urlError != null) {
      throw PluginUrlImportException(urlError);
    }

    final sourceUrl = rawUrl.trim();
    late Map<String, dynamic> json;
    try {
      json = await _fetcher.fetchManifestJson(sourceUrl);
    } on PluginManifestFetchException catch (error) {
      throw PluginUrlImportException(error.message);
    }

    try {
      _manifestValidator.validateRaw(json);
    } on PluginValidationException catch (error) {
      throw PluginUrlImportException(error.message);
    }

    final manifest = PluginManifest.fromJson(json).copyWith(
      installUrl: sourceUrl,
      sourceUrl: sourceUrl,
    );
    return PluginUrlImportResult(manifest: manifest, sourceUrl: sourceUrl);
  }
}
