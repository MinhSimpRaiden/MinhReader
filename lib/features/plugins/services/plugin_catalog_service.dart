import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import 'plugin_catalog_cache.dart';
import 'plugin_http_client.dart';
import 'plugin_repository.dart';

class PluginCatalogService {
  PluginCatalogService({
    PluginRepository? pluginRepository,
    PluginCatalogCache? cache,
    PluginHttpClient? httpClient,
  }) : _pluginRepository = pluginRepository ?? PluginRepository(),
       _cache = cache ?? PluginCatalogCache(),
       _httpClient = httpClient ?? PluginHttpClient();

  final PluginRepository _pluginRepository;
  final PluginCatalogCache _cache;
  final PluginHttpClient _httpClient;

  Future<PluginCatalogSyncResult> syncCatalog(String pluginId) async {
    final plugin = await _enabledApiPlugin(pluginId);
    final startPage = plugin.pagination.startPage;
    return _syncFromPage(plugin, startPage, reset: true);
  }

  Future<PluginCatalogSyncResult> syncNextPage(String pluginId) async {
    final plugin = await _enabledApiPlugin(pluginId);
    final current = await _cache.read(pluginId);
    final startPage = current.pageSynced <= 0
        ? plugin.pagination.startPage
        : current.pageSynced + 1;
    return _syncFromPage(plugin, startPage);
  }

  Future<PluginCatalogSyncResult> refreshCatalog(String pluginId) =>
      syncCatalog(pluginId);

  Future<List<PluginCatalogStory>> getCachedStories(String pluginId) async {
    final entry = await _cache.read(pluginId);
    return entry.stories;
  }

  Future<List<PluginCatalogStory>> searchCachedStories(
    String pluginId,
    String query,
  ) async {
    final stories = await getCachedStories(pluginId);
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return stories;
    return stories.where((story) {
      return story.title.toLowerCase().contains(cleanQuery) ||
          story.author.toLowerCase().contains(cleanQuery) ||
          story.description.toLowerCase().contains(cleanQuery) ||
          story.contentType.toLowerCase().contains(cleanQuery);
    }).toList();
  }

  Future<void> clearCache(String pluginId) => _cache.clear(pluginId);

  Future<PluginCatalogCacheEntry> getCacheEntry(String pluginId) =>
      _cache.read(pluginId);

  Future<PluginCatalogSyncResult> _syncFromPage(
    PluginManifest plugin,
    int startPage, {
    bool reset = false,
  }) async {
    final catalogEndpoint = plugin.endpoints['catalog'] ?? '';
    if (catalogEndpoint.trim().isEmpty) {
      throw const PluginHttpException('Plugin thiếu endpoint catalog');
    }
    final existing = reset
        ? PluginCatalogCacheEntry(pluginId: plugin.id)
        : await _cache.read(plugin.id);
    final merged = {for (final story in existing.stories) story.storyId: story};
    var page = startPage;
    var hasNextPage = true;
    var syncedCount = 0;
    var lastPageSynced = existing.pageSynced;
    final maxPages = plugin.pagination.maxPagesPerSync.clamp(1, 100);
    final limit = plugin.pagination.defaultLimit.clamp(1, 100);

    for (var i = 0; i < maxPages; i++) {
      final response = await _httpClient.getJson(
        plugin,
        catalogEndpoint,
        page: page,
        limit: limit,
      );
      final parsed = parseCatalogResponse(plugin, response);
      if (parsed.stories.isEmpty) {
        hasNextPage = false;
        break;
      }
      for (final story in parsed.stories) {
        if (!merged.containsKey(story.storyId)) syncedCount++;
        merged[story.storyId] = story;
      }
      lastPageSynced = page;
      hasNextPage = parsed.hasNextPage;
      if (!hasNextPage) break;
      page++;
    }

    final entry = PluginCatalogCacheEntry(
      pluginId: plugin.id,
      stories: merged.values.toList()
        ..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        ),
      lastSyncAt: DateTime.now(),
      pageSynced: lastPageSynced,
      hasNextPage: hasNextPage,
    );
    await _cache.write(entry);
    return PluginCatalogSyncResult(
      pluginId: plugin.id,
      syncedCount: syncedCount,
      totalCached: entry.stories.length,
      pageSynced: entry.pageSynced,
      hasNextPage: entry.hasNextPage,
    );
  }

  CatalogPage parseCatalogResponse(
    PluginManifest plugin,
    Map<String, dynamic> response,
  ) {
    final rawStories = response['stories'];
    final stories = <PluginCatalogStory>[];
    if (rawStories is List) {
      for (final item in rawStories) {
        if (item is! Map) continue;
        final json = item.map((key, value) => MapEntry('$key', value));
        final id = json['id'] as String? ?? json['storyId'] as String? ?? '';
        final title = json['title'] as String? ?? '';
        if (id.trim().isEmpty || title.trim().isEmpty) continue;
        final contentType =
            json['contentType'] as String? ??
            (plugin.contentType == 'mixed' ? 'text' : plugin.contentType);
        stories.add(
          PluginCatalogStory(
            pluginId: plugin.id,
            storyId: id,
            title: title,
            author: json['author'] as String? ?? 'Không rõ',
            description: json['description'] as String? ?? '',
            coverUrl: json['coverUrl'] as String?,
            contentType: contentType,
            status: json['status'] as String?,
            genres: (json['genres'] as List<dynamic>? ?? [])
                .map((genre) => '$genre')
                .toList(),
            updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
          ),
        );
      }
    }
    return CatalogPage(
      stories: stories,
      hasNextPage: response['hasNextPage'] as bool? ?? stories.isNotEmpty,
    );
  }

  Future<PluginManifest> _enabledApiPlugin(String pluginId) async {
    final plugins = await _pluginRepository.getInstalledPlugins();
    for (final plugin in plugins) {
      if (plugin.id == pluginId) {
        if (!plugin.isEnabled || plugin.sourceType != 'api_json') {
          throw const PluginHttpException('Plugin api_json chưa được bật');
        }
        return plugin;
      }
    }
    throw const PluginHttpException('Không tìm thấy plugin');
  }
}

class CatalogPage {
  const CatalogPage({required this.stories, required this.hasNextPage});

  final List<PluginCatalogStory> stories;
  final bool hasNextPage;
}
