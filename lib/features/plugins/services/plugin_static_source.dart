import '../../sources/models/source_models.dart';
import '../../sources/services/story_source.dart';
import '../models/plugin_manifest.dart';

class PluginStaticSource extends StorySource {
  const PluginStaticSource(this.manifest);

  final PluginManifest manifest;

  @override
  SourceInfo get info => SourceInfo(
    id: manifest.id,
    name: manifest.name,
    description:
        '${manifest.description}\nPlugin này không chạy mã thực thi, chỉ dùng cấu hình an toàn.',
    type: SourceType.mock,
    isEnabled: manifest.isEnabled,
  );

  @override
  Future<List<SourceSearchResult>> searchStories(String query) async {
    if (!manifest.isEnabled) return const [];
    final cleanQuery = query.trim().toLowerCase();
    final matchedStories = cleanQuery.isEmpty
        ? manifest.stories
        : manifest.stories.where((story) {
            return story.title.toLowerCase().contains(cleanQuery) ||
                story.author.toLowerCase().contains(cleanQuery) ||
                story.description.toLowerCase().contains(cleanQuery);
          });
    return [
      for (final story in matchedStories)
        SourceSearchResult(
          sourceId: manifest.id,
          story: story.toSourceStory(manifest.id),
        ),
    ];
  }

  @override
  Future<SourceStory?> getStoryDetail(String storyId) async {
    return _findStory(storyId)?.toSourceStory(manifest.id);
  }

  @override
  Future<List<SourceChapter>> getChapterList(String storyId) async {
    final story = _findStory(storyId);
    if (story == null) return const [];
    return [
      for (final chapter in story.chapters) chapter.toSourceChapter(story.id),
    ];
  }

  @override
  Future<String> getChapterContent(String storyId, String chapterId) async {
    final chapter = _findChapter(storyId, chapterId);
    return chapter?.content ?? '';
  }

  @override
  Future<List<String>> getChapterImages(
    String storyId,
    String chapterId,
  ) async {
    final chapter = _findChapter(storyId, chapterId);
    return chapter?.imagePaths ?? const [];
  }

  PluginStory? _findStory(String storyId) {
    for (final story in manifest.stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }

  PluginChapter? _findChapter(String storyId, String chapterId) {
    final story = _findStory(storyId);
    if (story == null) return null;
    for (final chapter in story.chapters) {
      if (chapter.id == chapterId) return chapter;
    }
    return null;
  }
}
