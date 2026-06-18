import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/features/comic/services/comic_storage_service.dart';
import 'package:minh_reader/features/plugins/models/plugin_manifest.dart';
import 'package:minh_reader/features/plugins/services/plugin_repository.dart';
import 'package:minh_reader/features/plugins/services/plugin_static_source.dart';
import 'package:minh_reader/features/plugins/services/plugin_storage.dart';
import 'package:minh_reader/features/plugins/services/plugin_validator.dart';
import 'package:minh_reader/features/sources/services/source_import_service.dart';
import 'package:minh_reader/features/sources/services/source_registry.dart';

void main() {
  test('validate plugin hợp lệ', () {
    PluginValidator().validateRaw(_validTextPlugin());
  });

  test('reject plugin thiếu id name version', () {
    for (final key in ['id', 'name', 'version']) {
      final json = _validTextPlugin()..remove(key);

      expect(
        () => PluginValidator().validateRaw(json),
        throwsA(isA<PluginValidationException>()),
      );
    }
  });

  test('reject plugin có field script javascript eval code', () {
    for (final key in ['script', 'javascript', 'eval', 'code']) {
      final json = _validTextPlugin()..[key] = 'bad';

      expect(
        () => PluginValidator().validateRaw(json),
        throwsA(isA<PluginValidationException>()),
      );
    }
  });

  test('plugin thiếu license vẫn hợp lệ', () {
    final json = _validTextPlugin()..remove('license');

    PluginValidator().validateRaw(json);
    expect(PluginManifest.fromJson(json).license, isEmpty);
  });

  test('import plugin local và search sample plugin', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_plugin_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final pluginFile = File(
      '${tempDir.path}${Platform.pathSeparator}plugin.json',
    );
    await pluginFile.writeAsString(jsonEncode(_validTextPlugin()));
    final repository = PluginRepository(
      storage: PluginStorage(directoryProvider: () async => tempDir),
    );

    final manifest = await repository.installFromFile(pluginFile);
    final sources = await repository.loadInstalledSources();
    final results = await sources.single.searchStories('đèn');

    expect(manifest.id, 'sample_test_text');
    expect(results, isNotEmpty);
  });

  test('install enable disable delete plugin', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_plugin_life_');
    addTearDown(() => tempDir.delete(recursive: true));
    final repository = PluginRepository(
      storage: PluginStorage(directoryProvider: () async => tempDir),
    );

    await repository.installFromJson(_validTextPlugin());
    expect(await repository.getInstalledPlugins(), hasLength(1));
    expect(await repository.getEnabledPlugins(), hasLength(1));

    await repository.disablePlugin('sample_test_text');
    expect(await repository.getEnabledPlugins(), isEmpty);

    await repository.enablePlugin('sample_test_text');
    expect(await repository.getEnabledPlugins(), hasLength(1));

    await repository.deletePlugin('sample_test_text');
    expect(await repository.getInstalledPlugins(), isEmpty);
  });

  test('installed plugin không làm hỏng source local demo cũ', () {
    final registry = SourceRegistry();

    expect(registry.byId('local_txt'), isNotNull);
    expect(registry.byId('local_epub'), isNotNull);
    expect(registry.byId('public_domain_demo'), isNotNull);
    expect(registry.byId('mock_comic'), isNotNull);
  });

  test('plugin source lấy detail chapter list và text content', () async {
    final manifest = PluginManifest.fromJson(_validTextPlugin());
    final source = PluginStaticSource(manifest);

    final detail = await source.getStoryDetail('story-1');
    final chapters = await source.getChapterList('story-1');
    final content = await source.getChapterContent('story-1', 'c1');

    expect(detail, isNotNull);
    expect(chapters, hasLength(1));
    expect(content, contains('ngọn đèn'));
  });

  test('plugin source lấy comic image list', () async {
    final manifest = PluginManifest.fromJson(_validComicPlugin());
    final source = PluginStaticSource(manifest);

    final images = await source.getChapterImages('comic-1', 'c1');

    expect(images, ['p1', 'p2']);
  });

  test('SourceImportService add comic plugin thành comic draft', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_plugin_comic_');
    addTearDown(() => tempDir.delete(recursive: true));
    final manifest = PluginManifest.fromJson(_validComicPlugin());
    final source = PluginStaticSource(manifest);
    final story = (await source.searchStories('vườn')).single.story;
    final importService = SourceImportService(
      comicStorageService: ComicStorageService(
        directoryProvider: () async => tempDir,
      ),
    );

    final draft = await importService.buildImportDraft(
      source: source,
      sourceStory: story,
    );

    expect(draft, isNotNull);
    expect(draft!.story.contentType, 'comic');
    expect(draft.comicChapters.single.imagePaths, hasLength(2));
    expect(
      await File(draft.comicChapters.single.imagePaths.first).exists(),
      isTrue,
    );
  });
}

Map<String, dynamic> _validTextPlugin() => {
  'id': 'sample_test_text',
  'name': 'Sample Test Text',
  'version': '1.0.0',
  'author': 'MinhReader Demo',
  'description': 'Demo text plugin',
  'contentType': 'text',
  'sourceType': 'static_json',
  'license': 'CC0-1.0',
  'language': 'vi',
  'stories': [
    {
      'id': 'story-1',
      'title': 'Ngọn đèn',
      'author': 'MinhReader Demo',
      'description': 'Demo',
      'contentType': 'text',
      'chapters': [
        {
          'id': 'c1',
          'title': 'Chương 1',
          'index': 0,
          'contentKind': 'text',
          'content': 'Một ngọn đèn nhỏ trong đêm.',
        },
      ],
    },
  ],
};

Map<String, dynamic> _validComicPlugin() => {
  'id': 'sample_test_comic',
  'name': 'Sample Test Comic',
  'version': '1.0.0',
  'author': 'MinhReader Demo',
  'description': 'Demo comic plugin',
  'contentType': 'comic',
  'sourceType': 'static_json',
  'license': 'CC0-1.0',
  'language': 'vi',
  'stories': [
    {
      'id': 'comic-1',
      'title': 'Khu vườn',
      'author': 'MinhReader Demo',
      'description': 'Demo',
      'contentType': 'comic',
      'chapters': [
        {
          'id': 'c1',
          'title': 'Chương ảnh',
          'index': 0,
          'contentKind': 'images',
          'imagePaths': ['p1', 'p2'],
        },
      ],
    },
  ],
};
