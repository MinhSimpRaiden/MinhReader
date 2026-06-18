class ComicChapter {
  const ComicChapter({
    required this.id,
    required this.storyId,
    required this.index,
    required this.title,
    required this.imagePaths,
    this.isRead = false,
  });

  final String id;
  final String storyId;
  final int index;
  final String title;
  final List<String> imagePaths;
  final bool isRead;

  ComicChapter copyWith({bool? isRead}) {
    return ComicChapter(
      id: id,
      storyId: storyId,
      index: index,
      title: title,
      imagePaths: imagePaths,
      isRead: isRead ?? this.isRead,
    );
  }

  factory ComicChapter.fromJson(Map<String, dynamic> json) {
    return ComicChapter(
      id: json['id'] as String,
      storyId: json['storyId'] as String,
      index: json['index'] as int,
      title: json['title'] as String? ?? 'Chương',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storyId': storyId,
    'index': index,
    'title': title,
    'imagePaths': imagePaths,
    'isRead': isRead,
  };
}
