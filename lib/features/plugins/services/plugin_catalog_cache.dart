import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/plugin_catalog.dart';

class PluginCatalogCache {
  PluginCatalogCache({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static const fileName = 'plugin_catalog_cache.json';

  final Future<Directory> Function() _directoryProvider;

  Future<File> file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<List<PluginCatalogCacheEntry>> readAll() async {
    final dataFile = await file();
    if (!await dataFile.exists()) return const [];
    final decoded = jsonDecode(await dataFile.readAsString());
    if (decoded is! Map<String, dynamic>) return const [];
    final entries = decoded['plugins'];
    if (entries is! List) return const [];
    return entries
        .map(
          (item) =>
              PluginCatalogCacheEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<PluginCatalogCacheEntry> read(String pluginId) async {
    final entries = await readAll();
    for (final entry in entries) {
      if (entry.pluginId == pluginId) return entry;
    }
    return PluginCatalogCacheEntry(pluginId: pluginId);
  }

  Future<void> write(PluginCatalogCacheEntry entry) async {
    final entries = await readAll();
    await _writeAll([
      entry,
      for (final item in entries)
        if (item.pluginId != entry.pluginId) item,
    ]);
  }

  Future<void> clear(String pluginId) async {
    final entries = await readAll();
    await _writeAll([
      for (final item in entries)
        if (item.pluginId != pluginId) item,
    ]);
  }

  Future<void> _writeAll(List<PluginCatalogCacheEntry> entries) async {
    final dataFile = await file();
    if (!await dataFile.parent.exists()) {
      await dataFile.parent.create(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    final tempFile = File('${dataFile.path}.tmp');
    await tempFile.writeAsString(
      encoder.convert({
        'plugins': entries.map((entry) => entry.toJson()).toList(),
      }),
      flush: true,
    );
    if (await dataFile.exists()) {
      await dataFile.delete();
    }
    await tempFile.rename(dataFile.path);
  }
}
