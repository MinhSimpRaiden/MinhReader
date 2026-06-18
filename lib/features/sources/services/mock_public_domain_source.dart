import '../models/source_models.dart';
import 'story_source.dart';

class MockPublicDomainSource extends StorySource {
  const MockPublicDomainSource();

  static const sourceId = 'public_domain_demo';

  static const _stories = <_MockStory>[
    _MockStory(
      id: 'demo-lantern-hill',
      title: 'Ngọn Đèn Trên Đồi',
      author: 'MinhReader Demo',
      description:
          'Một truyện mẫu tự viết về người gác đèn và chuyến đi qua thung lũng sương.',
      chapters: [
        _MockChapter(
          id: 'c1',
          title: 'Ánh sáng đầu tiên',
          content:
              'Buổi sáng trên đồi mở ra bằng một dải sương mỏng. An đặt chiếc đèn nhỏ bên cửa sổ và nhìn xuống con đường đất đỏ. Ở đó, những bước chân đầu tiên của ngày mới đang hiện ra rất chậm.\n\nNgười trong làng thường nói ngọn đèn ấy không phải để soi đường cho người đi gần, mà để nhắc người đi xa rằng vẫn có một nơi đang chờ họ trở về.',
        ),
        _MockChapter(
          id: 'c2',
          title: 'Thung lũng sương',
          content:
              'Khi chiều xuống, An đi qua thung lũng. Sương phủ lên cỏ như một tấm khăn trắng. Mỗi tiếng chim gọi vang lên rồi tan rất nhanh.\n\nCậu nhận ra mình không cần nhìn thấy toàn bộ con đường. Chỉ cần đủ ánh sáng cho vài bước trước mặt, người ta vẫn có thể tiếp tục.',
        ),
      ],
    ),
    _MockStory(
      id: 'demo-paper-boat',
      title: 'Con Thuyền Giấy',
      author: 'MinhReader Demo',
      description:
          'Truyện demo ngắn, nội dung tự viết, dùng để kiểm thử nguồn offline.',
      chapters: [
        _MockChapter(
          id: 'c1',
          title: 'Dòng nước nhỏ',
          content:
              'Mưa vừa tạnh. Trên con mương trước nhà, Bình thả một con thuyền giấy gấp từ trang vở cũ. Con thuyền nghiêng một chút, rồi tự tìm được dòng nước của mình.\n\nBình chạy theo nó, qua hàng cau, qua chiếc cầu gỗ, qua cả tiếng mẹ gọi từ sân sau.',
        ),
        _MockChapter(
          id: 'c2',
          title: 'Bến bờ',
          content:
              'Con thuyền dừng lại bên một bụi cỏ. Bình ngồi xuống, chạm nhẹ vào mép giấy đã mềm vì nước. Cậu bật cười, vì một chuyến đi rất nhỏ cũng có thể làm buổi chiều rộng hơn.\n\nCậu nhặt con thuyền lên, để dành cho cơn mưa tiếp theo.',
        ),
      ],
    ),
  ];

  @override
  SourceInfo get info => const SourceInfo(
    id: sourceId,
    name: 'Public Domain Demo',
    description: 'Nguồn này chỉ dùng dữ liệu mẫu offline.',
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
        ),
    ];
  }

  @override
  Future<String> getChapterContent(String storyId, String chapterId) async {
    final story = _findStory(storyId);
    if (story == null) return '';
    for (final chapter in story.chapters) {
      if (chapter.id == chapterId) return chapter.content;
    }
    return '';
  }

  _MockStory? _findStory(String storyId) {
    for (final story in _stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }
}

class _MockStory {
  const _MockStory({
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
  final List<_MockChapter> chapters;

  SourceStory toSourceStory() {
    return SourceStory(
      id: id,
      sourceId: MockPublicDomainSource.sourceId,
      title: title,
      author: author,
      description: description,
    );
  }
}

class _MockChapter {
  const _MockChapter({
    required this.id,
    required this.title,
    required this.content,
  });

  final String id;
  final String title;
  final String content;
}
