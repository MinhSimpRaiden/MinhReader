import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';

import '../../library/models/story.dart';
import '../models/comic_chapter.dart';
import 'comic_storage_service.dart';

class ComicImportException implements Exception {
  const ComicImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParsedComicDraft {
  const ParsedComicDraft({
    required this.story,
    required this.chapters,
    required this.filePath,
  });

  final Story story;
  final List<ComicChapter> chapters;
  final String filePath;
}

class ComicImportService {
  ComicImportService({ComicStorageService? storageService})
    : _storageService = storageService ?? ComicStorageService();

  static const maxFileBytes = 250 * 1024 * 1024;
  static const imageExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final ComicStorageService _storageService;

  Future<ParsedComicDraft?> pickAndParseComicFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['cbz', 'zip'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final path = result.files.single.path!;
    final lower = path.toLowerCase();
    if (!lower.endsWith('.cbz') && !lower.endsWith('.zip')) {
      throw const ComicImportException('File truyện tranh không hợp lệ');
    }

    final file = File(path);
    final size = await file.length();
    if (size == 0) {
      throw const ComicImportException('File truyện tranh không hợp lệ');
    }
    if (size > maxFileBytes) {
      throw const ComicImportException(
        'File truyện tranh quá lớn. Vui lòng chọn file dưới 250 MB.',
      );
    }

    final fallbackTitle = result.files.single.name.replaceFirst(
      RegExp(r'\.(cbz|zip)$', caseSensitive: false),
      '',
    );
    return parseArchiveFile(
      file,
      fallbackTitle: fallbackTitle.trim().isEmpty
          ? 'Truyện tranh chưa đặt tên'
          : fallbackTitle.trim(),
    );
  }

  Future<ParsedComicDraft> parseArchiveFile(
    File file, {
    required String fallbackTitle,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      return _parseArchive(
        archive,
        filePath: file.path,
        fallbackTitle: fallbackTitle,
      );
    } catch (_) {
      throw const ComicImportException('File truyện tranh không hợp lệ');
    }
  }

  Future<ParsedComicDraft> _parseArchive(
    Archive archive, {
    required String filePath,
    required String fallbackTitle,
  }) async {
    final imageFiles = archive.files.where((file) {
      if (!file.isFile) return false;
      return imageExtensions.contains(_extensionOf(file.name));
    }).toList()..sort((a, b) => naturalCompare(a.name, b.name));

    if (imageFiles.isEmpty) {
      throw const ComicImportException('Không tìm thấy ảnh trong file');
    }

    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    final storyDirectory = await _storageService.storyDirectory(storyId);
    final grouped = _groupByChapterFolder(imageFiles);
    final chapters = <ComicChapter>[];
    var chapterIndex = 0;

    for (final entry in grouped.entries) {
      final files = entry.value..sort((a, b) => naturalCompare(a.name, b.name));
      final imagePaths = <String>[];
      for (var pageIndex = 0; pageIndex < files.length; pageIndex++) {
        final source = files[pageIndex];
        final extension = _extensionOf(source.name);
        final chapterDir = Directory(
          '${storyDirectory.path}${Platform.pathSeparator}chapter_$chapterIndex',
        );
        if (!await chapterDir.exists()) {
          await chapterDir.create(recursive: true);
        }
        final target = File(
          '${chapterDir.path}${Platform.pathSeparator}${pageIndex.toString().padLeft(4, '0')}.$extension',
        );
        await target.writeAsBytes(source.content as List<int>, flush: true);
        imagePaths.add(target.path);
      }

      chapters.add(
        ComicChapter(
          id: '$storyId-$chapterIndex',
          storyId: storyId,
          index: chapterIndex,
          title: entry.key.isEmpty ? 'Chương ${chapterIndex + 1}' : entry.key,
          imagePaths: imagePaths,
        ),
      );
      chapterIndex++;
    }

    final now = DateTime.now();
    final story = Story(
      id: storyId,
      title: fallbackTitle,
      author: 'Không rõ',
      sourceType: 'local_comic',
      contentType: 'comic',
      createdAt: now,
      updatedAt: now,
      chapterCount: chapters.length,
      coverPath: chapters.first.imagePaths.isEmpty
          ? null
          : chapters.first.imagePaths.first,
    );

    return ParsedComicDraft(
      story: story,
      chapters: chapters,
      filePath: filePath,
    );
  }

  static Map<String, List<ArchiveFile>> _groupByChapterFolder(
    List<ArchiveFile> files,
  ) {
    final folderNames = files
        .map((file) => _chapterFolderOf(file.name))
        .where((folder) => folder.isNotEmpty)
        .toSet();
    final hasMultipleFolders = folderNames.length > 1;
    final grouped = <String, List<ArchiveFile>>{};
    for (final file in files) {
      final key = hasMultipleFolders ? _chapterFolderOf(file.name) : '';
      grouped.putIfAbsent(key, () => []).add(file);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => naturalCompare(a.key, b.key));
    return Map.fromEntries(entries);
  }

  static String _chapterFolderOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length <= 1) return '';
    return parts[parts.length - 2];
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static int naturalCompare(String a, String b) {
    final aParts = _naturalParts(a);
    final bParts = _naturalParts(b);
    final count = aParts.length < bParts.length ? aParts.length : bParts.length;
    for (var index = 0; index < count; index++) {
      final left = aParts[index];
      final right = bParts[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      final result = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : left.toLowerCase().compareTo(right.toLowerCase());
      if (result != 0) return result;
    }
    return aParts.length.compareTo(bParts.length);
  }

  static List<String> _naturalParts(String value) {
    return RegExp(
      r'\d+|\D+',
    ).allMatches(value).map((match) => match.group(0)!).toList();
  }
}
