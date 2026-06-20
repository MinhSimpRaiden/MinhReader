import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/features/comic/models/comic_chapter.dart';
import 'package:minh_reader/features/comic/services/comic_import_service.dart';
import 'package:minh_reader/features/library/models/story.dart';
import 'package:minh_reader/features/reader/models/chapter.dart';
import 'package:minh_reader/features/sources/models/source_models.dart';

void main() {
  test('natural sort sắp xếp 1, 2, 10 đúng thứ tự', () {
    final files = ['10.jpg', '1.jpg', '2.jpg']
      ..sort(ComicImportService.naturalCompare);

    expect(files, ['1.jpg', '2.jpg', '10.jpg']);
  });

  test('dữ liệu cũ không có contentType mặc định là text', () {
    final now = DateTime(2026, 6, 18, 9, 0).toIso8601String();
    final story = Story.fromJson({
      'id': 'story-1',
      'title': 'Truyện cũ',
      'author': 'Không rõ',
      'sourceType': 'local_txt',
      'createdAt': now,
      'updatedAt': now,
      'chapterCount': 1,
    });

    expect(story.contentType, 'text');
    expect(story.pluginId, isNull);
    expect(story.remoteStoryId, isNull);
  });

  test('Chapter old JSON missing remote fields is treated as loaded local', () {
    final chapter = Chapter.fromJson({
      'id': 'chapter-1',
      'storyId': 'story-1',
      'index': 0,
      'title': 'Chuong cu',
      'content': 'Noi dung cu',
      'wordCount': 3,
    });

    expect(chapter.isRemote, isFalse);
    expect(chapter.contentLoaded, isTrue);
    expect(chapter.remoteChapterId, isNull);
  });

  test('Story comic serialize deserialize đúng contentType', () {
    final now = DateTime(2026, 6, 18, 9, 0);
    final story = Story(
      id: 'comic-1',
      title: 'Comic',
      author: 'Không rõ',
      sourceType: 'local_comic',
      contentType: 'comic',
      createdAt: now,
      updatedAt: now,
      chapterCount: 1,
    );

    final restored = Story.fromJson(story.toJson());

    expect(restored.contentType, 'comic');
    expect(restored.sourceType, 'local_comic');
  });

  test('ComicChapter JSON đọc ghi đúng', () {
    const chapter = ComicChapter(
      id: 'comic-1-0',
      storyId: 'comic-1',
      index: 0,
      title: 'Chương 1',
      imagePaths: ['1.jpg', '2.jpg'],
      isRead: true,
    );

    final restored = ComicChapter.fromJson(chapter.toJson());

    expect(restored.imagePaths, ['1.jpg', '2.jpg']);
    expect(restored.isRead, isTrue);
    expect(restored.isRemote, isFalse);
    expect(restored.contentLoaded, isTrue);
  });

  test('SourceChapter hỗ trợ contentKind images', () {
    const chapter = SourceChapter(
      id: 'source-chapter-1',
      storyId: 'source-story-1',
      title: 'Chương ảnh',
      index: 0,
      contentKind: SourceContentKind.images,
      imagePaths: ['local-page.jpg'],
    );

    expect(chapter.contentKind, SourceContentKind.images);
    expect(chapter.imagePaths.single, 'local-page.jpg');
  });
}
