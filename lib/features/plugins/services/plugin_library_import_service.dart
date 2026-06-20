import '../../comic/models/comic_chapter.dart';
import '../../library/models/story.dart';
import '../../reader/models/chapter.dart';
import '../models/plugin_catalog.dart';
import '../models/plugin_runtime_models.dart';

class PluginLibraryImportDraft {
  const PluginLibraryImportDraft({
    required this.story,
    this.chapters = const [],
    this.comicChapters = const [],
  });

  final Story story;
  final List<Chapter> chapters;
  final List<ComicChapter> comicChapters;

  bool get isComic => story.contentType == 'comic';
}

class PluginLibraryImportService {
  static const sourceType = 'plugin_api_json';
  static const lazyTextPlaceholder =
      'Nội dung chương sẽ được tải khi đọc online.';

  PluginLibraryImportDraft buildDraft({
    required String pluginId,
    required PluginCatalogStory story,
    required List<PluginRuntimeChapter> chapters,
  }) {
    final storyId = DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final localStory = Story(
      id: storyId,
      title: story.title,
      author: story.author.trim().isEmpty ? 'Không rõ' : story.author,
      sourceType: sourceType,
      contentType: story.contentType == 'comic' ? 'comic' : 'text',
      createdAt: now,
      updatedAt: now,
      chapterCount: chapters.length,
      description: story.description,
      coverUrl: story.coverUrl,
      pluginId: pluginId,
      remoteStoryId: story.storyId,
    );

    if (localStory.contentType == 'comic') {
      return PluginLibraryImportDraft(
        story: localStory,
        comicChapters: [
          for (final chapter in chapters)
            ComicChapter(
              id: '$storyId-${chapter.index}',
              storyId: storyId,
              index: chapter.index,
              title: chapter.title,
              imagePaths: const [],
              pluginId: pluginId,
              remoteChapterId: chapter.id,
              isRemote: true,
              contentLoaded: false,
            ),
        ],
      );
    }

    return PluginLibraryImportDraft(
      story: localStory,
      chapters: [
        for (final chapter in chapters)
          Chapter(
            id: '$storyId-${chapter.index}',
            storyId: storyId,
            index: chapter.index,
            title: chapter.title,
            content: lazyTextPlaceholder,
            wordCount: 0,
            pluginId: pluginId,
            remoteChapterId: chapter.id,
            isRemote: true,
            contentLoaded: false,
          ),
      ],
    );
  }
}
