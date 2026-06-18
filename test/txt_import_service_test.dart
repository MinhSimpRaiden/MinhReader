import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/data/local/local_database.dart';
import 'package:minh_reader/features/import/services/epub_import_service.dart';
import 'package:minh_reader/features/import/services/txt_import_service.dart';
import 'package:minh_reader/features/library/models/story.dart';
import 'package:minh_reader/features/reader/models/bookmark.dart';
import 'package:minh_reader/features/reader/models/chapter.dart';
import 'package:minh_reader/features/settings/models/reading_settings.dart';

void main() {
  group('TxtImportService', () {
    test('tách chương tiếng Việt với Chương 1 và CHƯƠNG 2', () {
      final parsed = TxtImportService().parse(
        title: 'Truyện mẫu',
        author: '',
        content: '''
Chương 1
Nội dung mở đầu.

CHƯƠNG 2
Nội dung tiếp theo.
''',
      );

      expect(parsed.story.author, 'Không rõ');
      expect(parsed.chapters, hasLength(2));
      expect(parsed.chapters.first.title, 'Chương 1');
      expect(parsed.chapters.last.title, 'CHƯƠNG 2');
    });

    test('tách chương tiếng Anh với Chapter 1', () {
      final parsed = TxtImportService().parse(
        title: 'Story',
        author: 'Author',
        content: '''
Chapter 1
Hello world.
''',
      );

      expect(parsed.chapters, hasLength(1));
      expect(parsed.chapters.single.title, 'Chapter 1');
    });

    test('nội dung không có tiêu đề chương được chia thành phần tự động', () {
      final words = List.generate(4500, (index) => 'từ$index').join(' ');
      final parsed = TxtImportService().parse(
        title: 'Không chương',
        author: '',
        content: words,
      );

      expect(parsed.chapters, hasLength(2));
      expect(parsed.chapters.first.title, 'Phần 1');
      expect(parsed.chapters.last.title, 'Phần 2');
    });

    test('nội dung rỗng báo lỗi rõ ràng', () {
      expect(
        () =>
            TxtImportService().parse(title: 'Rỗng', author: '', content: '  '),
        throwsA(isA<TxtImportException>()),
      );
    });
  });

  group('EpubImportService', () {
    test('làm sạch HTML thành text dễ đọc', () {
      final text = EpubImportService.cleanHtml(
        '<h1>Chương 1</h1><p>Xin&nbsp;chào &amp; tạm biệt.</p><script>x()</script>',
      );

      expect(text, contains('Chương 1'));
      expect(text, contains('Xin chào & tạm biệt.'));
      expect(text, isNot(contains('<p>')));
      expect(text, isNot(contains('x()')));
    });

    test('fallback chia phần khi EPUB chỉ có một nội dung dài', () {
      final words = List.generate(4500, (index) => 'word$index').join(' ');
      final chapters = EpubImportService.buildChapters(
        storyId: 'epub-1',
        drafts: [EpubChapterDraft(title: 'Toàn bộ sách', content: words)],
      );

      expect(chapters, hasLength(2));
      expect(chapters.first.title, 'Phần 1');
      expect(chapters.last.title, 'Phần 2');
    });
  });

  test('LocalDatabase ghi và đọc dữ liệu trong thư mục tạm', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_reader_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final database = LocalDatabase(directoryProvider: () async => tempDir);
    final now = DateTime(2026, 6, 18, 9, 0);
    final story = Story(
      id: 'story-1',
      title: 'Truyện local',
      author: 'Tác giả',
      sourceType: 'local_epub',
      createdAt: now,
      updatedAt: now,
      lastReadScrollRatio: 0.42,
      chapterCount: 1,
    );
    final chapter = Chapter(
      id: 'story-1-0',
      storyId: 'story-1',
      index: 0,
      title: 'Chương 1',
      content: 'Nội dung',
      wordCount: 2,
    );

    await database.write(
      LocalDatabaseSnapshot(
        stories: [story],
        chapters: [chapter],
        bookmarks: [
          Bookmark(
            id: 'bookmark-1',
            storyId: 'story-1',
            chapterIndex: 0,
            chapterTitle: 'Chương 1',
            scrollRatio: 0.5,
            note: 'Đoạn hay',
            createdAt: now,
          ),
        ],
        readingSettings: ReadingSettings.defaults.copyWith(fontSize: 20),
      ),
    );

    final snapshot = await database.read();

    expect(snapshot.readWarning, isNull);
    expect(snapshot.stories.single.title, 'Truyện local');
    expect(snapshot.stories.single.sourceType, 'local_epub');
    expect(snapshot.stories.single.lastReadScrollRatio, 0.42);
    expect(snapshot.chapters.single.title, 'Chương 1');
    expect(snapshot.bookmarks.single.note, 'Đoạn hay');
    expect(snapshot.bookmarks.single.scrollRatio, 0.5);
    expect(snapshot.readingSettings.fontSize, 20);

    final raw = await File(
      '${tempDir.path}${Platform.pathSeparator}minh_reader_data.json',
    ).readAsString();
    expect(raw, contains('"dataVersion": 1'));
  });

  test('LocalDatabase đọc dữ liệu cũ không có dataVersion', () {
    final now = DateTime(2026, 6, 18, 9, 0).toIso8601String();
    final snapshot = LocalDatabase.snapshotFromJson({
      'stories': [
        {
          'id': 'old-story',
          'title': 'Dữ liệu cũ',
          'author': 'Không rõ',
          'sourceType': 'local_txt',
          'createdAt': now,
          'updatedAt': now,
          'chapterCount': 0,
        },
      ],
      'chapters': [],
    });

    expect(snapshot.dataVersion, 1);
    expect(snapshot.stories.single.title, 'Dữ liệu cũ');
    expect(snapshot.bookmarks, isEmpty);
    expect(snapshot.readingSettings.fontSize, 18);
  });

  test('LocalDatabase validate backup sai format', () {
    expect(
      () => LocalDatabase.snapshotFromJson({'stories': 'sai', 'chapters': []}),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('restore backup lỗi không xóa dữ liệu hiện tại', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'minh_reader_restore_bad_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final database = LocalDatabase(directoryProvider: () async => tempDir);
    final now = DateTime(2026, 6, 18, 9, 0);
    await database.write(
      LocalDatabaseSnapshot(
        stories: [
          Story(
            id: 'story-ok',
            title: 'Dữ liệu hiện tại',
            author: 'Tác giả',
            sourceType: 'local_txt',
            createdAt: now,
            updatedAt: now,
            chapterCount: 0,
          ),
        ],
        chapters: const [],
        bookmarks: const [],
        readingSettings: ReadingSettings.defaults,
      ),
    );
    final badBackup = File('${tempDir.path}${Platform.pathSeparator}bad.json');
    await badBackup.writeAsString('{ lỗi json');

    await expectLater(
      database.restoreFromJsonFile(badBackup),
      throwsA(isA<FormatException>()),
    );
    final snapshot = await database.read();
    expect(snapshot.stories.single.title, 'Dữ liệu hiện tại');
  });

  test('LocalDatabase không crash khi JSON lỗi', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'minh_reader_bad_json_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}minh_reader_data.json',
    );
    await file.writeAsString('{ lỗi json');
    final database = LocalDatabase(directoryProvider: () async => tempDir);

    final snapshot = await database.read();

    expect(snapshot.stories, isEmpty);
    expect(snapshot.chapters, isEmpty);
    expect(snapshot.readWarning, isNotNull);
    expect(await file.exists(), isTrue);
  });
}
