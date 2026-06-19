import 'plugin_catalog.dart';
import 'plugin_manifest.dart';

class PluginSearchResult {
  const PluginSearchResult({required this.plugin, required this.story});

  final PluginManifest plugin;
  final PluginCatalogStory story;
}

enum PluginSearchContentFilter { all, text, comic }

enum PluginSearchSortMode { updatedDesc, titleAz, authorAz, pluginName }
