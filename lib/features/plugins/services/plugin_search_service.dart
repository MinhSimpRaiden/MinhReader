import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import '../models/plugin_search_result.dart';

class PluginSearchService {
  const PluginSearchService();

  List<PluginSearchResult> search({
    required List<PluginManifest> plugins,
    required Map<String, List<PluginCatalogStory>> cachedStories,
    String query = '',
    String? pluginId,
    PluginSearchContentFilter contentFilter = PluginSearchContentFilter.all,
    PluginSearchSortMode sortMode = PluginSearchSortMode.updatedDesc,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final results = <PluginSearchResult>[];
    for (final plugin in plugins.where((plugin) => plugin.isEnabled)) {
      if (pluginId != null && plugin.id != pluginId) continue;
      final stories = cachedStories[plugin.id] ?? const <PluginCatalogStory>[];
      for (final story in stories) {
        if (!_matchesContentType(story, contentFilter)) continue;
        if (!_matchesQuery(plugin, story, cleanQuery)) continue;
        results.add(PluginSearchResult(plugin: plugin, story: story));
      }
    }
    results.sort((a, b) => _compare(a, b, sortMode));
    return results;
  }

  bool _matchesContentType(
    PluginCatalogStory story,
    PluginSearchContentFilter filter,
  ) {
    return switch (filter) {
      PluginSearchContentFilter.all => true,
      PluginSearchContentFilter.text => story.contentType == 'text',
      PluginSearchContentFilter.comic => story.contentType == 'comic',
    };
  }

  bool _matchesQuery(
    PluginManifest plugin,
    PluginCatalogStory story,
    String query,
  ) {
    if (query.isEmpty) return true;
    return story.title.toLowerCase().contains(query) ||
        story.author.toLowerCase().contains(query) ||
        story.description.toLowerCase().contains(query) ||
        story.genres.any((genre) => genre.toLowerCase().contains(query)) ||
        plugin.name.toLowerCase().contains(query);
  }

  int _compare(
    PluginSearchResult a,
    PluginSearchResult b,
    PluginSearchSortMode sortMode,
  ) {
    return switch (sortMode) {
      PluginSearchSortMode.updatedDesc =>
        (b.story.updatedAt ?? DateTime(0)).compareTo(
          a.story.updatedAt ?? DateTime(0),
        ),
      PluginSearchSortMode.titleAz => a.story.title.toLowerCase().compareTo(
        b.story.title.toLowerCase(),
      ),
      PluginSearchSortMode.authorAz => a.story.author.toLowerCase().compareTo(
        b.story.author.toLowerCase(),
      ),
      PluginSearchSortMode.pluginName => a.plugin.name.toLowerCase().compareTo(
        b.plugin.name.toLowerCase(),
      ),
    };
  }
}
