class Bookmark {
  const Bookmark({
    required this.id,
    required this.storyId,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.scrollRatio,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String storyId;
  final int chapterIndex;
  final String chapterTitle;
  final double scrollRatio;
  final DateTime createdAt;
  final String? note;

  Bookmark copyWith({String? chapterTitle, double? scrollRatio, String? note}) {
    return Bookmark(
      id: id,
      storyId: storyId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      scrollRatio: scrollRatio ?? this.scrollRatio,
      createdAt: createdAt,
      note: note,
    );
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      storyId: json['storyId'] as String,
      chapterIndex: json['chapterIndex'] as int,
      chapterTitle: json['chapterTitle'] as String? ?? 'Chương',
      scrollRatio: (json['scrollRatio'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storyId': storyId,
    'chapterIndex': chapterIndex,
    'chapterTitle': chapterTitle,
    'scrollRatio': scrollRatio,
    'createdAt': createdAt.toIso8601String(),
    'note': note,
  };
}
