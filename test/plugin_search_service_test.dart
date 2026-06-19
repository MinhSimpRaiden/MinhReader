import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/features/plugins/models/plugin_catalog.dart';
import 'package:minh_reader/features/plugins/models/plugin_manifest.dart';
import 'package:minh_reader/features/plugins/models/plugin_search_result.dart';
import 'package:minh_reader/features/plugins/services/plugin_search_service.dart';

void main() {
  const service = PluginSearchService();

  test('Plugin search lọc theo title author genre và plugin name', () {
    final plugins = [_plugin('p1', 'Nguồn Một'), _plugin('p2', 'Nguồn Hai')];
    final cache = {
      'p1': [
        _story('p1', 's1', 'Đèn trên đồi', 'An', ['fantasy'], 'text'),
      ],
      'p2': [
        _story('p2', 's2', 'Thuyền giấy', 'Bình', ['slice'], 'comic'),
      ],
    };

    expect(
      service.search(plugins: plugins, cachedStories: cache, query: 'đèn'),
      hasLength(1),
    );
    expect(
      service.search(plugins: plugins, cachedStories: cache, query: 'bình'),
      hasLength(1),
    );
    expect(
      service.search(plugins: plugins, cachedStories: cache, query: 'fantasy'),
      hasLength(1),
    );
    expect(
      service.search(
        plugins: plugins,
        cachedStories: cache,
        query: 'nguồn hai',
      ),
      hasLength(1),
    );
  });

  test('Plugin search chỉ dùng enabled plugins và lọc contentType', () {
    final plugins = [
      _plugin('p1', 'Enabled'),
      _plugin('p2', 'Disabled', enabled: false),
    ];
    final cache = {
      'p1': [
        _story('p1', 's1', 'Text story', 'A', [], 'text'),
        _story('p1', 's2', 'Comic story', 'B', [], 'comic'),
      ],
      'p2': [_story('p2', 's3', 'Hidden story', 'C', [], 'text')],
    };

    final text = service.search(
      plugins: plugins,
      cachedStories: cache,
      contentFilter: PluginSearchContentFilter.text,
    );
    final comic = service.search(
      plugins: plugins,
      cachedStories: cache,
      contentFilter: PluginSearchContentFilter.comic,
    );

    expect(text.map((item) => item.story.storyId), ['s1']);
    expect(comic.map((item) => item.story.storyId), ['s2']);
  });

  test('Plugin search sort A-Z', () {
    final plugins = [_plugin('p1', 'Nguồn')];
    final cache = {
      'p1': [
        _story('p1', 'b', 'Beta', 'B', [], 'text'),
        _story('p1', 'a', 'Alpha', 'A', [], 'text'),
      ],
    };

    final results = service.search(
      plugins: plugins,
      cachedStories: cache,
      sortMode: PluginSearchSortMode.titleAz,
    );

    expect(results.map((item) => item.story.title), ['Alpha', 'Beta']);
  });
}

PluginManifest _plugin(String id, String name, {bool enabled = true}) {
  return PluginManifest(
    id: id,
    name: name,
    version: '1.0.0',
    author: 'Tester',
    description: 'Demo',
    contentType: 'mixed',
    sourceType: 'api_json',
    license: 'Demo',
    language: 'vi',
    stories: const [],
    isEnabled: enabled,
  );
}

PluginCatalogStory _story(
  String pluginId,
  String storyId,
  String title,
  String author,
  List<String> genres,
  String contentType,
) {
  return PluginCatalogStory(
    pluginId: pluginId,
    storyId: storyId,
    title: title,
    author: author,
    description: 'Một mô tả demo',
    contentType: contentType,
    genres: genres,
    updatedAt: DateTime(2026, 6, 19),
  );
}
