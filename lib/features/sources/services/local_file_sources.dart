import '../models/source_models.dart';
import 'story_source.dart';

abstract class LocalFileSource extends StorySource {
  const LocalFileSource();

  @override
  Future<List<SourceSearchResult>> searchStories(String query) async {
    return const [];
  }

  @override
  Future<SourceStory?> getStoryDetail(String storyId) async {
    return null;
  }

  @override
  Future<List<SourceChapter>> getChapterList(String storyId) async {
    return const [];
  }

  @override
  Future<String> getChapterContent(String storyId, String chapterId) async {
    return '';
  }
}

class LocalTxtSource extends LocalFileSource {
  const LocalTxtSource();

  @override
  SourceInfo get info => const SourceInfo(
    id: 'local_txt',
    name: 'Local TXT',
    description: 'Nhập truyện từ file TXT hợp pháp trên thiết bị.',
    type: SourceType.local,
    isEnabled: true,
  );
}

class LocalEpubSource extends LocalFileSource {
  const LocalEpubSource();

  @override
  SourceInfo get info => const SourceInfo(
    id: 'local_epub',
    name: 'Local EPUB',
    description: 'Nhập truyện từ file EPUB hợp pháp trên thiết bị.',
    type: SourceType.local,
    isEnabled: true,
  );
}
