import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:minh_reader/features/comic/services/comic_storage_service.dart';
import 'package:minh_reader/features/sources/models/source_models.dart';
import 'package:minh_reader/features/sources/services/mock_comic_source.dart';
import 'package:minh_reader/features/sources/services/mock_public_domain_source.dart';
import 'package:minh_reader/features/sources/services/source_import_service.dart';
import 'package:minh_reader/features/sources/services/source_registry.dart';

void main() {
  test('SourceRegistry có local và mock source', () {
    final registry = SourceRegistry();

    expect(registry.byId('local_txt'), isNotNull);
    expect(registry.byId('local_epub'), isNotNull);
    expect(registry.byId(MockPublicDomainSource.sourceId), isNotNull);
    expect(registry.byId(MockComicSource.sourceId), isNotNull);
  });

  test('Mock source search trả về truyện mẫu', () async {
    const source = MockPublicDomainSource();

    final results = await source.searchStories('đèn');

    expect(results, isNotEmpty);
    expect(results.first.story.title, contains('Đèn'));
  });

  test('Mock source lấy danh sách chương', () async {
    const source = MockPublicDomainSource();

    final chapters = await source.getChapterList('demo-lantern-hill');

    expect(chapters, hasLength(2));
    expect(chapters.first.title, 'Ánh sáng đầu tiên');
  });

  test('Mock source lấy nội dung chương', () async {
    const source = MockPublicDomainSource();

    final content = await source.getChapterContent('demo-lantern-hill', 'c1');

    expect(content, contains('ngọn đèn'));
  });

  test(
    'SourceImportService thêm truyện từ mock source thành draft local',
    () async {
      const source = MockPublicDomainSource();
      final story = (await source.searchStories('thuyền')).first.story;

      final draft = await SourceImportService().buildImportDraft(
        source: source,
        sourceStory: story,
      );

      expect(draft, isNotNull);
      expect(draft!.story.sourceType, MockPublicDomainSource.sourceId);
      expect(draft.chapters, hasLength(2));
      expect(draft.chapters.first.storyId, draft.story.id);
    },
  );

  test('Mock comic source search trả về truyện tranh demo', () async {
    const source = MockComicSource();

    final results = await source.searchStories('mèo');

    expect(results, isNotEmpty);
    expect(results.first.story.contentType, 'comic');
  });

  test('Mock comic source lấy detail truyện tranh demo', () async {
    const source = MockComicSource();

    final detail = await source.getStoryDetail('demo-black-cat');

    expect(detail, isNotNull);
    expect(detail!.title, contains('Mèo'));
    expect(detail.contentType, 'comic');
  });

  test('Mock comic source lấy chapter list dạng images', () async {
    const source = MockComicSource();

    final chapters = await source.getChapterList('demo-black-cat');

    expect(chapters, hasLength(2));
    expect(chapters.first.contentKind, SourceContentKind.images);
    expect(chapters.first.imagePaths, hasLength(3));
  });

  test('Mock comic source lấy image list/page list', () async {
    const source = MockComicSource();

    final pages = await source.getChapterImages('demo-black-cat', 'c1');

    expect(pages, hasLength(3));
    expect(pages.first, contains('cat'));
  });

  test('SourceImportService thêm comic source thành draft local', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'minh_reader_mock_comic_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    const source = MockComicSource();
    final story = (await source.searchStories('mèo')).first.story;
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
    expect(draft.comicChapters, isNotEmpty);
    expect(draft.comicChapters.first.imagePaths, isNotEmpty);
    expect(
      await File(draft.comicChapters.first.imagePaths.first).exists(),
      isTrue,
    );
  });
}
