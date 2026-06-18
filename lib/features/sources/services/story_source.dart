import '../models/source_models.dart';

abstract class StorySource {
  const StorySource();

  SourceInfo get info;

  String get id => info.id;
  String get name => info.name;
  String get description => info.description;
  SourceType get type => info.type;
  bool get isEnabled => info.isEnabled;

  Future<List<SourceSearchResult>> searchStories(String query);

  Future<SourceStory?> getStoryDetail(String storyId);

  Future<List<SourceChapter>> getChapterList(String storyId);

  Future<String> getChapterContent(String storyId, String chapterId);

  Future<List<String>> getChapterImages(
    String storyId,
    String chapterId,
  ) async {
    return const [];
  }
}
