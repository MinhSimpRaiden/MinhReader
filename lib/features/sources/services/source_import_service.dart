import 'dart:io';

import 'package:image/image.dart' as img;

import '../../comic/models/comic_chapter.dart';
import '../../comic/services/comic_storage_service.dart';
import '../../library/models/story.dart';
import '../../reader/models/chapter.dart';
import '../models/source_models.dart';
import 'story_source.dart';

class SourceImportDraft {
  const SourceImportDraft({
    required this.story,
    this.chapters = const [],
    this.comicChapters = const [],
  });

  final Story story;
  final List<Chapter> chapters;
  final List<ComicChapter> comicChapters;

  bool get isComic => story.contentType == 'comic';
}

class SourceImportService {
  SourceImportService({ComicStorageService? comicStorageService})
    : _comicStorageService = comicStorageService ?? ComicStorageService();

  final ComicStorageService _comicStorageService;

  Future<SourceImportDraft?> buildImportDraft({
    required StorySource source,
    required SourceStory sourceStory,
  }) async {
    final sourceChapters = await source.getChapterList(sourceStory.id);
    if (sourceChapters.isEmpty) return null;

    return sourceStory.contentType == 'comic'
        ? _buildComicDraft(
            source: source,
            sourceStory: sourceStory,
            sourceChapters: sourceChapters,
          )
        : _buildTextDraft(
            source: source,
            sourceStory: sourceStory,
            sourceChapters: sourceChapters,
          );
  }

  Future<SourceImportDraft> _buildTextDraft({
    required StorySource source,
    required SourceStory sourceStory,
    required List<SourceChapter> sourceChapters,
  }) async {
    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final chapters = <Chapter>[];
    for (final sourceChapter in sourceChapters) {
      final content = await source.getChapterContent(
        sourceStory.id,
        sourceChapter.id,
      );
      chapters.add(
        Chapter(
          id: '$storyId-${sourceChapter.index}',
          storyId: storyId,
          index: sourceChapter.index,
          title: sourceChapter.title,
          content: content,
          wordCount: _wordCount(content),
        ),
      );
    }

    final story = Story(
      id: storyId,
      title: sourceStory.title,
      author: sourceStory.author.trim().isEmpty
          ? 'Không rõ'
          : sourceStory.author,
      sourceType: source.id,
      contentType: 'text',
      createdAt: now,
      updatedAt: now,
      chapterCount: chapters.length,
    );
    return SourceImportDraft(story: story, chapters: chapters);
  }

  Future<SourceImportDraft> _buildComicDraft({
    required StorySource source,
    required SourceStory sourceStory,
    required List<SourceChapter> sourceChapters,
  }) async {
    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final storyDirectory = await _comicStorageService.storyDirectory(storyId);
    final comicChapters = <ComicChapter>[];

    for (final sourceChapter in sourceChapters) {
      final imageIds = await source.getChapterImages(
        sourceStory.id,
        sourceChapter.id,
      );
      final pageIds = imageIds.isEmpty ? sourceChapter.imagePaths : imageIds;
      final imagePaths = <String>[];
      final chapterDirectory = Directory(
        '${storyDirectory.path}${Platform.pathSeparator}chapter_${sourceChapter.index}',
      );
      if (!await chapterDirectory.exists()) {
        await chapterDirectory.create(recursive: true);
      }
      for (var pageIndex = 0; pageIndex < pageIds.length; pageIndex++) {
        final target = File(
          '${chapterDirectory.path}${Platform.pathSeparator}${pageIndex.toString().padLeft(4, '0')}.png',
        );
        await target.writeAsBytes(
          _buildDemoPagePng(
            storyTitle: sourceStory.title,
            chapterTitle: sourceChapter.title,
            pageIndex: pageIndex,
            pageId: pageIds[pageIndex],
          ),
          flush: true,
        );
        imagePaths.add(target.path);
      }
      comicChapters.add(
        ComicChapter(
          id: '$storyId-${sourceChapter.index}',
          storyId: storyId,
          index: sourceChapter.index,
          title: sourceChapter.title,
          imagePaths: imagePaths,
        ),
      );
    }

    final story = Story(
      id: storyId,
      title: sourceStory.title,
      author: sourceStory.author.trim().isEmpty
          ? 'Không rõ'
          : sourceStory.author,
      sourceType: source.id,
      contentType: 'comic',
      createdAt: now,
      updatedAt: now,
      chapterCount: comicChapters.length,
      coverPath: comicChapters.first.imagePaths.isEmpty
          ? null
          : comicChapters.first.imagePaths.first,
    );
    return SourceImportDraft(story: story, comicChapters: comicChapters);
  }

  List<int> _buildDemoPagePng({
    required String storyTitle,
    required String chapterTitle,
    required int pageIndex,
    required String pageId,
  }) {
    final page = img.Image(720, 1040);
    final colors = [
      img.getColor(245, 238, 220),
      img.getColor(224, 237, 242),
      img.getColor(238, 226, 242),
      img.getColor(226, 239, 226),
    ];
    final background = colors[pageIndex % colors.length];
    final ink = img.getColor(35, 38, 42);
    final muted = img.getColor(90, 96, 105);
    page.fill(background);

    img.drawString(page, img.arial_24, 36, 28, _ascii(storyTitle), color: ink);
    img.drawString(
      page,
      img.arial_14,
      38,
      66,
      '${_ascii(chapterTitle)} - Page ${pageIndex + 1}',
      color: muted,
    );

    final panelTop = 120;
    for (var panel = 0; panel < 3; panel++) {
      final top = panelTop + panel * 285;
      final left = 48 + panel * 18;
      final right = 672 - panel * 12;
      final bottom = top + 220;
      img.fillRect(
        page,
        left,
        top,
        right,
        bottom,
        img.getColor(255, 255, 255, 180),
      );
      img.drawRect(page, left, top, right, bottom, ink);
      img.drawLine(page, left + 24, top + 42, right - 24, top + 42, muted);
      img.drawLine(
        page,
        left + 42,
        bottom - 54,
        right - 42,
        bottom - 54,
        muted,
      );
      img.drawString(
        page,
        img.arial_14,
        left + 28,
        top + 70,
        'Demo panel ${panel + 1}',
        color: ink,
      );
    }
    img.drawString(page, img.arial_14, 38, 1000, pageId, color: muted);
    return img.encodePng(page);
  }

  String _ascii(String value) {
    return value
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _wordCount(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
  }
}
