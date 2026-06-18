import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../models/plugin_manifest.dart';
import 'plugin_static_source.dart';
import 'plugin_storage.dart';
import 'plugin_validator.dart';

class PluginRepository {
  PluginRepository({PluginStorage? storage, PluginValidator? validator})
    : _storage = storage ?? PluginStorage(),
      _validator = validator ?? PluginValidator();

  final PluginStorage _storage;
  final PluginValidator _validator;

  Future<List<PluginManifest>> loadInstalled() => _storage.read();

  Future<List<PluginStaticSource>> loadInstalledSources() async {
    final manifests = await loadInstalled();
    return manifests
        .where((manifest) => manifest.isEnabled)
        .map(PluginStaticSource.new)
        .toList();
  }

  Future<PluginManifest?> pickAndInstallPlugin() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;
    return installFromFile(File(result.files.single.path!));
  }

  Future<PluginManifest> installFromFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const PluginValidationException('Plugin không hợp lệ');
    }
    return installFromJson(decoded);
  }

  Future<PluginManifest> installFromAsset(String assetPath) async {
    final decoded = jsonDecode(await rootBundle.loadString(assetPath));
    if (decoded is! Map<String, dynamic>) {
      throw const PluginValidationException('Plugin không hợp lệ');
    }
    return installFromJson(decoded);
  }

  Future<PluginManifest> installFromJson(Map<String, dynamic> json) async {
    _validator.validateRaw(json);
    final manifest = PluginManifest.fromJson(json);
    final manifests = await loadInstalled();
    final updated = [
      manifest,
      ...manifests.where((item) => item.id != manifest.id),
    ];
    await _storage.write(updated);
    return manifest;
  }

  Future<void> setEnabled(String pluginId, bool enabled) async {
    final manifests = await loadInstalled();
    await _storage.write([
      for (final manifest in manifests)
        manifest.id == pluginId
            ? manifest.copyWith(isEnabled: enabled)
            : manifest,
    ]);
  }

  Future<void> delete(String pluginId) async {
    final manifests = await loadInstalled();
    await _storage.write([
      for (final manifest in manifests)
        if (manifest.id != pluginId) manifest,
    ]);
  }
}
