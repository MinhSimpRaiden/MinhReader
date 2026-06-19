import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import '../models/plugin_runtime_models.dart';
import 'plugin_http_client.dart';
import 'plugin_repository.dart';

class PluginRuntimeService {
  PluginRuntimeService({
    PluginRepository? pluginRepository,
    PluginHttpClient? httpClient,
  }) : _pluginRepository = pluginRepository ?? PluginRepository(),
       _httpClient = httpClient ?? PluginHttpClient();

  final PluginRepository _pluginRepository;
  final PluginHttpClient _httpClient;

  Future<PluginCatalogStory> getStoryDetail(
    String pluginId,
    String storyId,
  ) async {
    final plugin = await _enabledApiPlugin(pluginId);
    final endpoint = plugin.endpoints['detail'] ?? '';
    if (endpoint.isEmpty) {
      throw const PluginHttpException('Plugin thiếu endpoint detail');
    }
    final response = await _httpClient.getJson(
      plugin,
      endpoint,
      storyId: storyId,
    );
    return parseStoryDetail(plugin, response);
  }

  Future<List<PluginRuntimeChapter>> getChapterList(
    String pluginId,
    String storyId,
  ) async {
    final plugin = await _enabledApiPlugin(pluginId);
    final endpoint = plugin.endpoints['chapters'] ?? '';
    if (endpoint.isEmpty) {
      throw const PluginHttpException('Plugin thiếu endpoint chapters');
    }
    final response = await _httpClient.getJson(
      plugin,
      endpoint,
      storyId: storyId,
    );
    return parseChapterList(response);
  }

  Future<PluginTextChapter> getTextChapterContent(
    String pluginId,
    String chapterId,
  ) async {
    final plugin = await _enabledApiPlugin(pluginId);
    final endpoint = plugin.endpoints['chapterContent'] ?? '';
    if (endpoint.isEmpty) {
      throw const PluginHttpException('Plugin thiếu endpoint chapterContent');
    }
    final response = await _httpClient.getJson(
      plugin,
      endpoint,
      chapterId: chapterId,
    );
    return parseTextChapter(response);
  }

  Future<PluginComicChapterImages> getComicChapterImages(
    String pluginId,
    String chapterId,
  ) async {
    final plugin = await _enabledApiPlugin(pluginId);
    final endpoint = plugin.endpoints['chapterImages'] ?? '';
    if (endpoint.isEmpty) {
      throw const PluginHttpException('Plugin thiếu endpoint chapterImages');
    }
    final response = await _httpClient.getJson(
      plugin,
      endpoint,
      chapterId: chapterId,
    );
    return parseComicImages(response);
  }

  PluginCatalogStory parseStoryDetail(
    PluginManifest plugin,
    Map<String, dynamic> response,
  ) {
    return PluginCatalogStory(
      pluginId: plugin.id,
      storyId: response['id'] as String? ?? '',
      title: response['title'] as String? ?? '',
      author: response['author'] as String? ?? 'Không rõ',
      description: response['description'] as String? ?? '',
      coverUrl: response['coverUrl'] as String?,
      contentType:
          response['contentType'] as String? ??
          (plugin.contentType == 'mixed' ? 'text' : plugin.contentType),
      status: response['status'] as String?,
      genres: (response['genres'] as List<dynamic>? ?? [])
          .map((genre) => '$genre')
          .toList(),
      updatedAt: DateTime.tryParse(response['updatedAt'] as String? ?? ''),
    );
  }

  List<PluginRuntimeChapter> parseChapterList(Map<String, dynamic> response) {
    final chapters = response['chapters'];
    if (chapters is! List) return const [];
    return [
      for (final item in chapters)
        if (item is Map)
          PluginRuntimeChapter(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? 'Chương',
            index: item['index'] as int? ?? 0,
            updatedAt: DateTime.tryParse(item['updatedAt'] as String? ?? ''),
          ),
    ].where((chapter) => chapter.id.trim().isNotEmpty).toList();
  }

  PluginTextChapter parseTextChapter(Map<String, dynamic> response) {
    return PluginTextChapter(
      id: response['id'] as String? ?? '',
      title: response['title'] as String? ?? 'Chương',
      index: response['index'] as int? ?? 0,
      content: response['content'] as String? ?? '',
    );
  }

  PluginComicChapterImages parseComicImages(Map<String, dynamic> response) {
    return PluginComicChapterImages(
      id: response['id'] as String? ?? '',
      title: response['title'] as String? ?? 'Chương',
      index: response['index'] as int? ?? 0,
      images: (response['images'] as List<dynamic>? ?? [])
          .map((image) => '$image')
          .toList(),
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
