import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/data/local/local_database.dart';
import 'package:minh_reader/data/repositories/library_repository.dart';
import 'package:minh_reader/features/library/providers/app_controller.dart';
import 'package:minh_reader/features/plugins/models/plugin_catalog.dart';
import 'package:minh_reader/features/plugins/models/plugin_runtime_models.dart';
import 'package:minh_reader/features/plugins/services/plugin_library_import_service.dart';

void main() {
  test('Add text plugin story tạo metadata và không tải chapter content', () {
    final service = PluginLibraryImportService();
    final draft = service.buildDraft(
      pluginId: 'plugin_text',
      story: _story(contentType: 'text'),
      chapters: _chapters,
    );

    expect(draft.isComic, isFalse);
    expect(draft.story.sourceType, PluginLibraryImportService.sourceType);
    expect(draft.story.pluginId, 'plugin_text');
    expect(draft.story.remoteStoryId, 'remote_story');
    expect(draft.story.coverUrl, 'https://example.com/cover.jpg');
    expect(draft.chapters, hasLength(2));
    expect(draft.chapters.first.remoteChapterId, 'c1');
    expect(draft.chapters.first.isRemote, isTrue);
    expect(draft.chapters.first.contentLoaded, isFalse);
    expect(
      draft.chapters.first.content,
      PluginLibraryImportService.lazyTextPlaceholder,
    );
    expect(draft.chapters.first.wordCount, 0);
  });

  test('Add comic plugin story tạo metadata và không tải chapterImages', () {
    final service = PluginLibraryImportService();
    final draft = service.buildDraft(
      pluginId: 'plugin_comic',
      story: _story(contentType: 'comic'),
      chapters: _chapters,
    );

    expect(draft.isComic, isTrue);
    expect(draft.story.contentType, 'comic');
    expect(draft.comicChapters, hasLength(2));
    expect(draft.comicChapters.first.remoteChapterId, 'c1');
    expect(draft.comicChapters.first.isRemote, isTrue);
    expect(draft.comicChapters.first.contentLoaded, isFalse);
    expect(draft.comicChapters.first.imagePaths, isEmpty);
    expect(draft.comicChapters.first.imageUrls, isEmpty);
  });

  test('AppController không tạo duplicate theo pluginId + remoteStoryId', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'minh_reader_plugin_dup_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final controller = AppController(
      LibraryRepository(
        database: LocalDatabase(directoryProvider: () async => tempDir),
      ),
    );
    await controller.load();
    final service = PluginLibraryImportService();
    final firstDraft = service.buildDraft(
      pluginId: 'plugin_text',
      story: _story(contentType: 'text'),
      chapters: _chapters,
    );
    final first = await controller.addPluginTextStory(
      firstDraft.story,
      firstDraft.chapters,
    );
    final secondDraft = service.buildDraft(
      pluginId: 'plugin_text',
      story: _story(contentType: 'text'),
      chapters: _chapters,
    );
    final second = await controller.addPluginTextStory(
      secondDraft.story,
      secondDraft.chapters,
    );

    expect(second.id, first.id);
    expect(controller.stories, hasLength(1));
  });

  test('AppController cache text chapter lazy thành contentLoaded=true', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'minh_reader_plugin_cache_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final controller = AppController(
      LibraryRepository(
        database: LocalDatabase(directoryProvider: () async => tempDir),
      ),
    );
    await controller.load();
    final service = PluginLibraryImportService();
    final draft = service.buildDraft(
      pluginId: 'plugin_text',
      story: _story(contentType: 'text'),
      chapters: _chapters,
    );
    final story = await controller.addPluginTextStory(
      draft.story,
      draft.chapters,
    );
    final chapter = controller.chaptersFor(story.id).first;

    await controller.cacheRemoteChapterContent(
      storyId: story.id,
      chapterId: chapter.id,
      content: 'Nội dung thật của chương.',
    );

    final cached = controller.chaptersFor(story.id).first;
    expect(cached.contentLoaded, isTrue);
    expect(cached.content, 'Nội dung thật của chương.');
    expect(cached.wordCount, 5);
  });
}

PluginCatalogStory _story({required String contentType}) {
  return PluginCatalogStory(
    pluginId: 'plugin_source',
    storyId: 'remote_story',
    title: 'Truyện plugin',
    author: 'Tác giả',
    description: 'Mô tả',
    coverUrl: 'https://example.com/cover.jpg',
    contentType: contentType,
  );
}

const _chapters = [
  PluginRuntimeChapter(id: 'c1', title: 'Chương 1', index: 0),
  PluginRuntimeChapter(id: 'c2', title: 'Chương 2', index: 1),
];
