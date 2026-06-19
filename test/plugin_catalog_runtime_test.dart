import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minh_reader/features/plugins/models/plugin_manifest.dart';
import 'package:minh_reader/features/plugins/services/plugin_catalog_cache.dart';
import 'package:minh_reader/features/plugins/services/plugin_catalog_service.dart';
import 'package:minh_reader/features/plugins/services/plugin_http_client.dart';
import 'package:minh_reader/features/plugins/services/plugin_repository.dart';
import 'package:minh_reader/features/plugins/services/plugin_runtime_service.dart';
import 'package:minh_reader/features/plugins/services/plugin_storage.dart';
import 'package:minh_reader/features/plugins/services/plugin_validator.dart';

void main() {
  test('validate api_json plugin hợp lệ', () {
    PluginValidator().validateRaw(_validApiPlugin());
  });

  test('reject api_json thiếu baseUrl', () {
    final json = _validApiPlugin()..remove('baseUrl');

    expect(
      () => PluginValidator().validateRaw(json),
      throwsA(isA<PluginValidationException>()),
    );
  });

  test('reject baseUrl không phải http/https', () {
    final json = _validApiPlugin()..['baseUrl'] = 'file:///tmp/plugin';

    expect(
      () => PluginValidator().validateRaw(json),
      throwsA(isA<PluginValidationException>()),
    );
  });

  test('PluginHttpClient build endpoint URL thay placeholder đúng', () {
    final manifest = PluginManifest.fromJson(_validApiPlugin());
    final uri = PluginHttpClient().buildUrl(
      manifest,
      '/stories/{storyId}/chapters/{chapterId}?q={query}&page={page}&limit={limit}',
      storyId: 'story 1',
      chapterId: 'chapter/1',
      query: 'đèn sáng',
      page: 2,
      limit: 10,
    );

    expect(
      uri.toString(),
      contains('https://example.com/api/stories/story%201'),
    );
    expect(uri.toString(), contains('chapter%2F1'));
    expect(uri.toString(), contains('q=%C4%91%C3%A8n%20s%C3%A1ng'));
    expect(uri.toString(), contains('page=2'));
    expect(uri.toString(), contains('limit=10'));
  });

  test('parse catalog response bỏ item thiếu id/title', () {
    final manifest = PluginManifest.fromJson(_validApiPlugin());
    final service = PluginCatalogService();
    final page = service.parseCatalogResponse(manifest, {
      'hasNextPage': true,
      'stories': [
        {
          'id': 'story_001',
          'title': 'Tên truyện',
          'description': 'Mô tả',
          'contentType': 'text',
        },
        {'id': 'missing-title'},
        {'title': 'Missing id'},
      ],
    });

    expect(page.hasNextPage, isTrue);
    expect(page.stories, hasLength(1));
    expect(page.stories.single.author, 'Không rõ');
  });

  test('sync catalog cache stories và không tải chapter content', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_catalog_');
    addTearDown(() => tempDir.delete(recursive: true));
    var requestedChapter = false;
    final repository = PluginRepository(
      storage: PluginStorage(directoryProvider: () async => tempDir),
    );
    await repository.installFromJson(_validApiPlugin());
    final client = PluginHttpClient(
      client: MockClient((request) async {
        if (request.url.path.contains('chapters')) requestedChapter = true;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'page': 1,
              'limit': 20,
              'hasNextPage': false,
              'stories': [
                {
                  'id': 'story_001',
                  'title': 'Tên truyện',
                  'author': 'Tác giả',
                  'description': 'Mô tả',
                  'contentType': 'text',
                  'updatedAt': '2026-06-18T10:00:00Z',
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final cache = PluginCatalogCache(directoryProvider: () async => tempDir);
    final service = PluginCatalogService(
      pluginRepository: repository,
      cache: cache,
      httpClient: client,
    );

    final result = await service.syncCatalog('demo_catalog_source');
    final stories = await service.getCachedStories('demo_catalog_source');
    final searched = await service.searchCachedStories(
      'demo_catalog_source',
      'tên',
    );

    expect(result.syncedCount, 1);
    expect(stories, hasLength(1));
    expect(searched, hasLength(1));
    expect(requestedChapter, isFalse);
  });

  test('runtime parse chapter list text chapter và comic images', () {
    final service = PluginRuntimeService();

    final chapters = service.parseChapterList({
      'storyId': 'story_001',
      'chapters': [
        {'id': 'chapter_001', 'title': 'Chương 1', 'index': 0},
      ],
    });
    final text = service.parseTextChapter({
      'id': 'chapter_001',
      'title': 'Chương 1',
      'index': 0,
      'content': 'Nội dung chương...',
    });
    final comic = service.parseComicImages({
      'id': 'comic_chapter_001',
      'title': 'Chương 1',
      'index': 0,
      'images': ['https://example.com/001.jpg'],
    });

    expect(chapters.single.id, 'chapter_001');
    expect(text.content, contains('Nội dung'));
    expect(comic.images.single, 'https://example.com/001.jpg');
  });
}

Map<String, dynamic> _validApiPlugin() => {
  'schemaVersion': 1,
  'id': 'demo_catalog_source',
  'name': 'Demo Catalog Source',
  'version': '1.0.0',
  'author': 'MinhReader',
  'description': 'Nguồn demo dùng catalog endpoint.',
  'contentType': 'mixed',
  'sourceType': 'api_json',
  'language': 'vi',
  'license': 'Demo / Authorized API',
  'homepage': 'https://example.com',
  'baseUrl': 'https://example.com/api',
  'isAdultContent': false,
  'features': {
    'catalog': true,
    'search': true,
    'latest': true,
    'detail': true,
    'chapters': true,
    'readText': true,
    'readComic': true,
  },
  'endpoints': {
    'catalog': '/stories?page={page}&limit={limit}',
    'latest': '/stories/latest?page={page}&limit={limit}',
    'search': '/stories/search?q={query}&page={page}&limit={limit}',
    'detail': '/stories/{storyId}',
    'chapters': '/stories/{storyId}/chapters',
    'chapterContent': '/chapters/{chapterId}',
    'chapterImages': '/comic-chapters/{chapterId}/images',
  },
  'pagination': {
    'type': 'page',
    'startPage': 1,
    'defaultLimit': 20,
    'maxPagesPerSync': 5,
  },
  'rateLimit': {'requestsPerMinute': 30},
};
