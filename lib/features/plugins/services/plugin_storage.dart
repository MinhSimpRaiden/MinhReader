import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/plugin_manifest.dart';

class PluginStorage {
  PluginStorage({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static const fileName = 'installed_plugins.json';
  static const legacyFileName = 'minh_reader_plugins.json';

  final Future<Directory> Function() _directoryProvider;

  Future<File> file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<List<PluginManifest>> read() async {
    var dataFile = await file();
    if (!await dataFile.exists()) {
      final directory = await _directoryProvider();
      final legacyFile = File(
        '${directory.path}${Platform.pathSeparator}$legacyFileName',
      );
      if (await legacyFile.exists()) dataFile = legacyFile;
    }
    if (!await dataFile.exists()) return const [];
    final decoded = jsonDecode(await dataFile.readAsString());
    if (decoded is! Map<String, dynamic>) return const [];
    final manifests = decoded['plugins'];
    if (manifests is! List) return const [];
    return manifests
        .map((item) => PluginManifest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> write(List<PluginManifest> manifests) async {
    final dataFile = await file();
    if (!await dataFile.parent.exists()) {
      await dataFile.parent.create(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await dataFile.writeAsString(
      encoder.convert({
        'plugins': manifests.map((manifest) => manifest.toJson()).toList(),
      }),
      flush: true,
    );
  }
}
