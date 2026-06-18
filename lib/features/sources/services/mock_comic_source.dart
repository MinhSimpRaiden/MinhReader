import '../models/source_models.dart';
import 'story_source.dart';

class MockComicSource extends StorySource {
  const MockComicSource();

  static const sourceId = 'mock_comic';

  static const _stories = <_MockComicStory>[
    _MockComicStory(
      id: 'demo-black-cat',
      title: 'Hành trình của Mèo Đen',
      author: 'MinhReader Demo',
      description:
          'Truyện tranh demo offline tự tạo về một chuyến đi qua những mái nhà yên tĩnh.',
      chapters: [
        _MockComicChapter(
          id: 'c1',
          title: 'Mái nhà đầu tiên',
          pages: ['cat-c1-p1', 'cat-c1-p2', 'cat-c1-p3'],
        ),
        _MockComicChapter(
          id: 'c2',
          title: 'Ánh đèn cuối phố',
          pages: ['cat-c2-p1', 'cat-c2-p2', 'cat-c2-p3', 'cat-c2-p4'],
        ),
      ],
    ),
    _MockComicStory(
      id: 'demo-star-library',
      title: 'Thư viện Ánh Sao',
      author: 'MinhReader Demo',
      description:
          'Một truyện tranh mẫu offline về căn phòng đọc sách mở cửa khi trời đầy sao.',
      chapters: [
        _MockComicChapter(
          id: 'c1',
          title: 'Kệ sách sáng',
          pages: ['star-c1-p1', 'star-c1-p2', 'star-c1-p3'],
        ),
      ],
    ),
  ];

  @override
  SourceInfo get info => const SourceInfo(
    id: sourceId,
    name: 'Truyện tranh demo',
    description:
        'Nguồn truyện tranh mẫu offline, chỉ dùng dữ liệu demo trong app',
    type: SourceType.mock,
    isEnabled: true,
  );

  @override
  Future<List<SourceSearchResult>> searchStories(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    final matchedStories = cleanQuery.isEmpty
        ? _stories
        : _stories.where((story) {
            return story.title.toLowerCase().contains(cleanQuery) ||
                story.author.toLowerCase().contains(cleanQuery) ||
                story.description.toLowerCase().contains(cleanQuery);
          });
    return [
      for (final story in matchedStories)
        SourceSearchResult(sourceId: sourceId, story: story.toSourceStory()),
    ];
  }

  @override
  Future<SourceStory?> getStoryDetail(String storyId) async {
    return _findStory(storyId)?.toSourceStory();
  }

  @override
  Future<List<SourceChapter>> getChapterList(String storyId) async {
    final story = _findStory(storyId);
    if (story == null) return const [];
    return [
      for (var index = 0; index < story.chapters.length; index++)
        SourceChapter(
          id: story.chapters[index].id,
          storyId: story.id,
          title: story.chapters[index].title,
          index: index,
          contentKind: SourceContentKind.images,
          imagePaths: story.chapters[index].pages,
        ),
    ];
  }

  @override
  Future<String> getChapterContent(String storyId, String chapterId) async {
    return '';
  }

  @override
  Future<List<String>> getChapterImages(
    String storyId,
    String chapterId,
  ) async {
    final story = _findStory(storyId);
    if (story == null) return const [];
    for (final chapter in story.chapters) {
      if (chapter.id == chapterId) return chapter.pages;
    }
    return const [];
  }

  _MockComicStory? _findStory(String storyId) {
    for (final story in _stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }
}

class _MockComicStory {
  const _MockComicStory({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.chapters,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final List<_MockComicChapter> chapters;

  SourceStory toSourceStory() {
    return SourceStory(
      id: id,
      sourceId: MockComicSource.sourceId,
      title: title,
      author: author,
      description: description,
      contentType: 'comic',
    );
  }
}

class _MockComicChapter {
  const _MockComicChapter({
    required this.id,
    required this.title,
    required this.pages,
  });

  final String id;
  final String title;
  final List<String> pages;
}
