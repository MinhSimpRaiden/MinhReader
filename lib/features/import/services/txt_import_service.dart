import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../library/models/story.dart';
import '../../reader/models/chapter.dart';

class TxtImportException implements Exception {
  const TxtImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PickedTxtStory {
  const PickedTxtStory({
    required this.defaultTitle,
    required this.content,
    required this.filePath,
  });

  final String defaultTitle;
  final String content;
  final String filePath;
}

class ParsedStory {
  const ParsedStory({required this.story, required this.chapters});

  final Story story;
  final List<Chapter> chapters;
}

class TxtImportService {
  static const maxFileBytes = 20 * 1024 * 1024;

  static final _chapterTitlePattern = RegExp(
    r'^\s*((chương|chuong|chapter)\s+[\divxlcdm]+[\.: -]?.*)$',
    caseSensitive: false,
    multiLine: true,
  );

  Future<PickedTxtStory?> pickTxtFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final path = result.files.single.path!;
    if (!path.toLowerCase().endsWith('.txt')) {
      throw const TxtImportException('Vui lòng chọn đúng file TXT.');
    }

    final file = File(path);
    final size = await file.length();
    if (size == 0) {
      throw const TxtImportException(
        'File TXT đang rỗng, chưa có nội dung để nhập.',
      );
    }
    if (size > maxFileBytes) {
      throw const TxtImportException(
        'File TXT quá lớn. Vui lòng chọn file dưới 20 MB để app xử lý ổn định.',
      );
    }

    final bytes = await file.readAsBytes();
    final content = _decodeText(bytes);
    if (content.trim().isEmpty) {
      throw const TxtImportException(
        'File TXT đang rỗng, chưa có nội dung để nhập.',
      );
    }

    final name = result.files.single.name.replaceFirst(
      RegExp(r'\.txt$', caseSensitive: false),
      '',
    );

    return PickedTxtStory(
      defaultTitle: name.trim().isEmpty ? 'Truyện chưa đặt tên' : name.trim(),
      content: content,
      filePath: path,
    );
  }

  ParsedStory parse({
    required String title,
    required String author,
    required String content,
  }) {
    if (content.trim().isEmpty) {
      throw const TxtImportException(
        'Nội dung truyện đang rỗng, chưa thể lưu.',
      );
    }

    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final chapters = _parseChapters(storyId, content);
    final story = Story(
      id: storyId,
      title: title.trim().isEmpty ? 'Truyện chưa đặt tên' : title.trim(),
      author: author.trim().isEmpty ? 'Không rõ' : author.trim(),
      sourceType: 'local_txt',
      createdAt: now,
      updatedAt: now,
      chapterCount: chapters.length,
    );

    return ParsedStory(story: story, chapters: chapters);
  }

  static List<Chapter> splitContentIntoChapters({
    required String storyId,
    required String content,
  }) {
    final words = content
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return [
        Chapter(
          id: '$storyId-0',
          storyId: storyId,
          index: 0,
          title: 'Chương 1',
          content: content.trim(),
          wordCount: 0,
        ),
      ];
    }

    const targetWords = 4000;
    final chapters = <Chapter>[];
    for (var start = 0; start < words.length; start += targetWords) {
      final end = (start + targetWords).clamp(0, words.length);
      final index = chapters.length;
      final text = words.sublist(start, end).join(' ');
      chapters.add(
        Chapter(
          id: '$storyId-$index',
          storyId: storyId,
          index: index,
          title: 'Phần ${index + 1}',
          content: text,
          wordCount: _wordCount(text),
        ),
      );
    }
    return chapters;
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  List<Chapter> _parseChapters(String storyId, String content) {
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final matches = _chapterTitlePattern.allMatches(normalized).toList();
    if (matches.isEmpty) {
      return splitContentIntoChapters(storyId: storyId, content: normalized);
    }

    final chapters = <Chapter>[];
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final nextStart = i + 1 < matches.length
          ? matches[i + 1].start
          : normalized.length;
      final title = match.group(1)?.trim() ?? 'Chương ${i + 1}';
      final body = normalized.substring(match.end, nextStart).trim();
      chapters.add(
        Chapter(
          id: '$storyId-$i',
          storyId: storyId,
          index: i,
          title: title,
          content: body.isEmpty ? title : body,
          wordCount: _wordCount(body),
        ),
      );
    }
    return chapters;
  }

  static int _wordCount(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }
}
