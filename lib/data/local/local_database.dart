import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../features/comic/models/comic_chapter.dart';
import '../../features/library/models/story.dart';
import '../../features/reader/models/bookmark.dart';
import '../../features/reader/models/chapter.dart';
import '../../features/settings/models/reading_settings.dart';

class LocalDatabaseSnapshot {
  const LocalDatabaseSnapshot({
    required this.stories,
    required this.chapters,
    required this.bookmarks,
    this.comicChapters = const [],
    required this.readingSettings,
    this.dataVersion = LocalDatabase.currentDataVersion,
    this.readWarning,
  });

  final List<Story> stories;
  final List<Chapter> chapters;
  final List<Bookmark> bookmarks;
  final List<ComicChapter> comicChapters;
  final ReadingSettings readingSettings;
  final int dataVersion;
  final String? readWarning;
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalDatabase {
  LocalDatabase({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  static const fileName = 'minh_reader_data.json';
  static const currentDataVersion = 1;

  final Future<Directory> Function() _directoryProvider;

  Future<File> file() async {
    final directory = await _directoryProvider();
    return File('${directory.path}${Platform.pathSeparator}$fileName');
  }

  Future<Directory> documentsDirectory() => _directoryProvider();

  Future<LocalDatabaseSnapshot> read() async {
    final dataFile = await file();
    final backupFile = File('${dataFile.path}.bak');
    if (!await dataFile.exists() && await backupFile.exists()) {
      await backupFile.copy(dataFile.path);
    }
    if (!await dataFile.exists()) return _empty();

    try {
      final raw = await dataFile.readAsString();
      if (raw.trim().isEmpty) return _empty();
      return snapshotFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _empty(
        warning:
            'Không thể đọc dữ liệu cũ vì file JSON bị lỗi. App đang dùng dữ liệu mặc định và vẫn giữ file cũ.',
      );
    }
  }

  Future<void> write(LocalDatabaseSnapshot snapshot) async {
    final dataFile = await file();
    await _writeSnapshotToFile(snapshot, dataFile);
  }

  Future<File> createAutomaticBackup() async {
    final dataFile = await file();
    final directory = await _directoryProvider();
    final backupFile = File(
      '${directory.path}${Platform.pathSeparator}${backupFileName(prefix: 'minh_reader_auto_backup')}',
    );
    if (await dataFile.exists()) {
      return dataFile.copy(backupFile.path);
    }
    await _writeSnapshotToFile(_empty(), backupFile);
    return backupFile;
  }

  Future<void> restoreFromJsonFile(File sourceFile) async {
    final raw = await sourceFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException('File sao lưu không hợp lệ');
    }
    final snapshot = snapshotFromJson(decoded);
    await createAutomaticBackup();
    await write(snapshot);
  }

  Future<void> _writeSnapshotToFile(
    LocalDatabaseSnapshot snapshot,
    File targetFile,
  ) async {
    if (!await targetFile.parent.exists()) {
      await targetFile.parent.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    final payload = encoder.convert(snapshotToJson(snapshot));

    final tempFile = File('${targetFile.path}.tmp');
    final backupFile = File('${targetFile.path}.bak');
    await tempFile.writeAsString(payload, flush: true);
    if (await targetFile.exists()) {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      await targetFile.rename(backupFile.path);
    }
    await tempFile.rename(targetFile.path);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }

  static Map<String, dynamic> snapshotToJson(LocalDatabaseSnapshot snapshot) {
    return {
      'dataVersion': currentDataVersion,
      'stories': snapshot.stories.map((story) => story.toJson()).toList(),
      'chapters': snapshot.chapters.map((chapter) => chapter.toJson()).toList(),
      'comicChapters': snapshot.comicChapters
          .map((chapter) => chapter.toJson())
          .toList(),
      'bookmarks': snapshot.bookmarks
          .map((bookmark) => bookmark.toJson())
          .toList(),
      'readingSettings': snapshot.readingSettings.toJson(),
    };
  }

  static LocalDatabaseSnapshot snapshotFromJson(Map<String, dynamic> json) {
    final version = json['dataVersion'] as int? ?? 0;
    final migrated = _migrate(json, version);

    final storiesRaw = migrated['stories'];
    final chaptersRaw = migrated['chapters'];
    if (storiesRaw is! List || chaptersRaw is! List) {
      throw const BackupValidationException('File sao lưu không hợp lệ');
    }

    final stories = storiesRaw
        .map((item) => Story.fromJson(item as Map<String, dynamic>))
        .toList();
    final chapters = chaptersRaw
        .map((item) => Chapter.fromJson(item as Map<String, dynamic>))
        .toList();
    final bookmarks = (migrated['bookmarks'] as List<dynamic>? ?? [])
        .map((item) => Bookmark.fromJson(item as Map<String, dynamic>))
        .toList();
    final comicChapters = (migrated['comicChapters'] as List<dynamic>? ?? [])
        .map((item) => ComicChapter.fromJson(item as Map<String, dynamic>))
        .toList();
    final settings = migrated['readingSettings'] == null
        ? ReadingSettings.defaults
        : ReadingSettings.fromJson(
            migrated['readingSettings'] as Map<String, dynamic>,
          );

    return LocalDatabaseSnapshot(
      stories: stories,
      chapters: chapters,
      comicChapters: comicChapters,
      bookmarks: bookmarks,
      readingSettings: settings,
      dataVersion: currentDataVersion,
    );
  }

  static Map<String, dynamic> _migrate(Map<String, dynamic> json, int version) {
    final migrated = Map<String, dynamic>.from(json);
    if (version <= 0) {
      migrated['dataVersion'] = 1;
      migrated['bookmarks'] ??= <dynamic>[];
      migrated['comicChapters'] ??= <dynamic>[];
      migrated['readingSettings'] ??= ReadingSettings.defaults.toJson();
    }
    return migrated;
  }

  static String backupFileName({String prefix = 'minh_reader_backup'}) {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}';
    return '${prefix}_$stamp.json';
  }

  LocalDatabaseSnapshot _empty({String? warning}) {
    return LocalDatabaseSnapshot(
      stories: const [],
      chapters: const [],
      comicChapters: const [],
      bookmarks: const [],
      readingSettings: ReadingSettings.defaults,
      readWarning: warning,
    );
  }
}
