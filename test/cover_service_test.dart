import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:minh_reader/features/library/models/story.dart';
import 'package:minh_reader/features/library/services/cover_service.dart';

void main() {
  group('Story coverPath JSON', () {
    test('đọc ghi coverPath đúng', () {
      final now = DateTime(2026, 6, 18, 9, 0);
      final story = Story(
        id: 'story-1',
        title: 'Truyện có bìa',
        author: 'Tác giả',
        sourceType: 'local_epub',
        createdAt: now,
        updatedAt: now,
        chapterCount: 1,
        coverPath: 'covers/story-1.png',
      );

      final restored = Story.fromJson(story.toJson());

      expect(restored.coverPath, 'covers/story-1.png');
    });

    test('dữ liệu cũ thiếu coverPath vẫn đọc được', () {
      final now = DateTime(2026, 6, 18, 9, 0).toIso8601String();

      final story = Story.fromJson({
        'id': 'old-story',
        'title': 'Truyện cũ',
        'author': 'Không rõ',
        'sourceType': 'local_txt',
        'createdAt': now,
        'updatedAt': now,
        'chapterCount': 0,
      });

      expect(story.coverPath, isNull);
    });
  });

  group('CoverService', () {
    test('EPUB không có cover không làm lỗi', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'minh_reader_cover_null_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final service = CoverService(directoryProvider: () async => tempDir);

      final coverPath = await service.saveEpubCover(
        storyId: 'story-no-cover',
        coverImage: null,
      );

      expect(coverPath, isNull);
    });

    test('lưu cover EPUB vào thư mục covers', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'minh_reader_cover_save_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final service = CoverService(directoryProvider: () async => tempDir);

      final coverPath = await service.saveEpubCover(
        storyId: 'story-cover',
        coverImage: img.Image(2, 2),
      );

      expect(coverPath, isNotNull);
      expect(await File(coverPath!).exists(), isTrue);
      expect(coverPath, contains('covers'));
      expect(service.canReadCover(coverPath), isTrue);
    });
  });
}
