class Story {
  const Story({
    required this.id,
    required this.title,
    required this.author,
    required this.sourceType,
    required this.createdAt,
    required this.updatedAt,
    this.contentType = 'text',
    this.lastReadAt,
    this.lastReadChapterIndex = 0,
    this.lastReadScrollRatio = 0,
    required this.chapterCount,
    this.coverPath,
    this.description,
    this.coverUrl,
    this.pluginId,
    this.remoteStoryId,
  });

  final String id;
  final String title;
  final String author;
  final String sourceType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String contentType;
  final DateTime? lastReadAt;
  final int lastReadChapterIndex;
  final double lastReadScrollRatio;
  final int chapterCount;
  final String? coverPath;
  final String? description;
  final String? coverUrl;
  final String? pluginId;
  final String? remoteStoryId;

  bool get isPluginRemote =>
      sourceType == 'plugin_api_json' &&
      pluginId != null &&
      remoteStoryId != null;

  Story copyWith({
    String? title,
    String? author,
    DateTime? updatedAt,
    String? contentType,
    DateTime? lastReadAt,
    int? lastReadChapterIndex,
    double? lastReadScrollRatio,
    int? chapterCount,
    String? coverPath,
    String? description,
    String? coverUrl,
    String? pluginId,
    String? remoteStoryId,
    bool clearCoverPath = false,
  }) {
    return Story(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      sourceType: sourceType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contentType: contentType ?? this.contentType,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      lastReadChapterIndex: lastReadChapterIndex ?? this.lastReadChapterIndex,
      lastReadScrollRatio: lastReadScrollRatio ?? this.lastReadScrollRatio,
      chapterCount: chapterCount ?? this.chapterCount,
      coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      pluginId: pluginId ?? this.pluginId,
      remoteStoryId: remoteStoryId ?? this.remoteStoryId,
    );
  }

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: json['id'] as String,
      title: json['title'] as String,
      author: json['author'] as String? ?? 'Không rõ',
      sourceType: json['sourceType'] as String? ?? 'local_txt',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      contentType: json['contentType'] as String? ?? 'text',
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.parse(json['lastReadAt'] as String),
      lastReadChapterIndex: json['lastReadChapterIndex'] as int? ?? 0,
      lastReadScrollRatio:
          (json['lastReadScrollRatio'] as num?)?.toDouble() ?? 0,
      chapterCount: json['chapterCount'] as int? ?? 0,
      coverPath: json['coverPath'] as String?,
      description: json['description'] as String?,
      coverUrl: json['coverUrl'] as String?,
      pluginId: json['pluginId'] as String?,
      remoteStoryId: json['remoteStoryId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'sourceType': sourceType,
    'contentType': contentType,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastReadAt': lastReadAt?.toIso8601String(),
    'lastReadChapterIndex': lastReadChapterIndex,
    'lastReadScrollRatio': lastReadScrollRatio,
    'chapterCount': chapterCount,
    'coverPath': coverPath,
    'description': description,
    'coverUrl': coverUrl,
    'pluginId': pluginId,
    'remoteStoryId': remoteStoryId,
  };
}
