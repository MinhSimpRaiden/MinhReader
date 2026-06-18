import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:file_picker/file_picker.dart';

import '../../library/models/story.dart';
import '../../library/services/cover_service.dart';
import '../../reader/models/chapter.dart';
import 'txt_import_service.dart';

class EpubImportException implements Exception {
  const EpubImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParsedEpubDraft {
  const ParsedEpubDraft({
    required this.story,
    required this.chapters,
    required this.filePath,
    required this.coverAvailable,
  });

  final Story story;
  final List<Chapter> chapters;
  final String filePath;
  final bool coverAvailable;
}

class EpubImportService {
  EpubImportService({CoverService? coverService})
    : _coverService = coverService ?? CoverService();

  static const maxFileBytes = 60 * 1024 * 1024;

  final CoverService _coverService;

  Future<ParsedEpubDraft?> pickAndParseEpubFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['epub'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final path = result.files.single.path!;
    if (!path.toLowerCase().endsWith('.epub')) {
      throw const EpubImportException('Vui lòng chọn đúng file EPUB.');
    }

    final file = File(path);
    final size = await file.length();
    if (size == 0) {
      throw const EpubImportException(
        'File EPUB đang rỗng, chưa có nội dung để nhập.',
      );
    }
    if (size > maxFileBytes) {
      throw const EpubImportException(
        'File EPUB quá lớn. Vui lòng chọn file dưới 60 MB để app xử lý ổn định.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final epubBook = await EpubReader.readBook(bytes);
      final fallbackTitle = result.files.single.name.replaceFirst(
        RegExp(r'\.epub$', caseSensitive: false),
        '',
      );
      final parsed = parseBook(
        epubBook,
        fallbackTitle: fallbackTitle.trim().isEmpty
            ? 'Truyện EPUB chưa đặt tên'
            : fallbackTitle.trim(),
        filePath: path,
      );
      final coverPath = await _coverService.saveEpubCover(
        storyId: parsed.story.id,
        coverImage: epubBook.CoverImage,
      );
      return ParsedEpubDraft(
        story: parsed.story.copyWith(coverPath: coverPath),
        chapters: parsed.chapters,
        filePath: parsed.filePath,
        coverAvailable: coverPath != null,
      );
    } on EpubImportException {
      rethrow;
    } catch (_) {
      throw const EpubImportException('Không thể đọc file EPUB này.');
    }
  }

  ParsedEpubDraft parseBook(
    EpubBook epubBook, {
    required String fallbackTitle,
    required String filePath,
  }) {
    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final title = _cleanMetadata(epubBook.Title) ?? fallbackTitle;
    final author = _cleanMetadata(epubBook.Author) ?? 'Không rõ';
    final chapterDrafts = _chapterDraftsFromBook(epubBook);
    if (chapterDrafts.isEmpty) {
      throw const EpubImportException('File EPUB không có nội dung đọc được.');
    }

    final chapters = buildChapters(storyId: storyId, drafts: chapterDrafts);
    final story = Story(
      id: storyId,
      title: title,
      author: author,
      sourceType: 'local_epub',
      createdAt: now,
      updatedAt: now,
      chapterCount: chapters.length,
    );

    return ParsedEpubDraft(
      story: story,
      chapters: chapters,
      filePath: filePath,
      coverAvailable: epubBook.CoverImage != null,
    );
  }

  static List<Chapter> buildChapters({
    required String storyId,
    required List<EpubChapterDraft> drafts,
  }) {
    final cleanDrafts = drafts
        .map(
          (draft) => EpubChapterDraft(
            title: draft.title.trim().isEmpty ? 'Chương' : draft.title.trim(),
            content: cleanHtml(draft.content),
          ),
        )
        .where((draft) => draft.content.trim().isNotEmpty)
        .toList();

    if (cleanDrafts.isEmpty) {
      return const [];
    }
    if (cleanDrafts.length == 1) {
      final content = cleanDrafts.single.content;
      final wordCount = _wordCount(content);
      if (wordCount > 4000) {
        return TxtImportService.splitContentIntoChapters(
          storyId: storyId,
          content: content,
        );
      }
    }

    return [
      for (var index = 0; index < cleanDrafts.length; index++)
        Chapter(
          id: '$storyId-$index',
          storyId: storyId,
          index: index,
          title: cleanDrafts[index].title,
          content: cleanDrafts[index].content,
          wordCount: _wordCount(cleanDrafts[index].content),
        ),
    ];
  }

  static String cleanHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</\s*h[1-6]\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'</\s*div\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = _decodeHtmlEntities(text);
    return text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  List<EpubChapterDraft> _chapterDraftsFromBook(EpubBook epubBook) {
    final drafts = <EpubChapterDraft>[];
    for (final chapter in epubBook.Chapters ?? <EpubChapter>[]) {
      _appendChapterDrafts(chapter, drafts);
    }
    if (drafts.isNotEmpty) return drafts;

    final htmlFiles = epubBook.Content?.Html?.values ?? const [];
    var index = 1;
    for (final file in htmlFiles) {
      final content = cleanHtml(file.Content ?? '');
      if (content.isEmpty) continue;
      drafts.add(
        EpubChapterDraft(
          title: file.FileName?.trim().isNotEmpty == true
              ? file.FileName!
              : 'Phần ${index++}',
          content: content,
        ),
      );
    }
    return drafts;
  }

  void _appendChapterDrafts(
    EpubChapter chapter,
    List<EpubChapterDraft> drafts,
  ) {
    final title =
        _cleanMetadata(chapter.Title) ?? 'Chương ${drafts.length + 1}';
    final content = cleanHtml(chapter.HtmlContent ?? '');
    if (content.isNotEmpty) {
      drafts.add(EpubChapterDraft(title: title, content: content));
    }
    for (final child in chapter.SubChapters ?? <EpubChapter>[]) {
      _appendChapterDrafts(child, drafts);
    }
  }

  static String? _cleanMetadata(String? value) {
    final cleaned = cleanHtml(value ?? '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static String _decodeHtmlEntities(String value) {
    return value.replaceAllMapped(RegExp(r'&(#x?[0-9a-fA-F]+|\w+);'), (match) {
      final entity = match.group(1)!;
      if (entity.startsWith('#x') || entity.startsWith('#X')) {
        final code = int.tryParse(entity.substring(2), radix: 16);
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      if (entity.startsWith('#')) {
        final code = int.tryParse(entity.substring(1));
        return code == null ? match.group(0)! : String.fromCharCode(code);
      }
      return switch (entity) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        'nbsp' => ' ',
        _ => match.group(0)!,
      };
    });
  }

  static int _wordCount(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }
}

class EpubChapterDraft {
  const EpubChapterDraft({required this.title, required this.content});

  final String title;
  final String content;
}
