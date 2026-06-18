class Chapter {
  const Chapter({
    required this.id,
    required this.storyId,
    required this.index,
    required this.title,
    required this.content,
    required this.wordCount,
    this.isRead = false,
  });

  final String id;
  final String storyId;
  final int index;
  final String title;
  final String content;
  final int wordCount;
  final bool isRead;

  Chapter copyWith({bool? isRead}) {
    return Chapter(
      id: id,
      storyId: storyId,
      index: index,
      title: title,
      content: content,
      wordCount: wordCount,
      isRead: isRead ?? this.isRead,
    );
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as String,
      storyId: json['storyId'] as String,
      index: json['index'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      wordCount: json['wordCount'] as int? ?? 0,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storyId': storyId,
    'index': index,
    'title': title,
    'content': content,
    'wordCount': wordCount,
    'isRead': isRead,
  };
}
