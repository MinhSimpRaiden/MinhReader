enum SourceType { local, mock }

enum SourceContentKind { text, images }

class SourceInfo {
  const SourceInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.isEnabled,
  });

  final String id;
  final String name;
  final String description;
  final SourceType type;
  final bool isEnabled;

  String get typeLabel => switch (type) {
    SourceType.local => 'Nguồn local',
    SourceType.mock => 'Nguồn demo',
  };
}

class SourceStory {
  const SourceStory({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.author,
    required this.description,
    this.contentType = 'text',
  });

  final String id;
  final String sourceId;
  final String title;
  final String author;
  final String description;
  final String contentType;
}

class SourceChapter {
  const SourceChapter({
    required this.id,
    required this.storyId,
    required this.title,
    required this.index,
    this.contentKind = SourceContentKind.text,
    this.imagePaths = const [],
  });

  final String id;
  final String storyId;
  final String title;
  final int index;
  final SourceContentKind contentKind;
  final List<String> imagePaths;
}

class SourceSearchResult {
  const SourceSearchResult({required this.sourceId, required this.story});

  final String sourceId;
  final SourceStory story;
}
