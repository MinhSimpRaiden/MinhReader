class Chapter {
  const Chapter({
    required this.id,
    required this.storyId,
    required this.index,
    required this.title,
    required this.content,
    required this.wordCount,
    this.isRead = false,
    this.pluginId,
    this.remoteChapterId,
    this.isRemote = false,
    this.contentLoaded = true,
  });

  final String id;
  final String storyId;
  final int index;
  final String title;
  final String content;
  final int wordCount;
  final bool isRead;
  final String? pluginId;
  final String? remoteChapterId;
  final bool isRemote;
  final bool contentLoaded;

  Chapter copyWith({
    String? content,
    int? wordCount,
    bool? isRead,
    String? pluginId,
    String? remoteChapterId,
    bool? isRemote,
    bool? contentLoaded,
  }) {
    return Chapter(
      id: id,
      storyId: storyId,
      index: index,
      title: title,
      content: content ?? this.content,
      wordCount: wordCount ?? this.wordCount,
      isRead: isRead ?? this.isRead,
      pluginId: pluginId ?? this.pluginId,
      remoteChapterId: remoteChapterId ?? this.remoteChapterId,
      isRemote: isRemote ?? this.isRemote,
      contentLoaded: contentLoaded ?? this.contentLoaded,
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
      pluginId: json['pluginId'] as String?,
      remoteChapterId: json['remoteChapterId'] as String?,
      isRemote: json['isRemote'] as bool? ?? false,
      contentLoaded: json['contentLoaded'] as bool? ?? true,
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
    'pluginId': pluginId,
    'remoteChapterId': remoteChapterId,
    'isRemote': isRemote,
    'contentLoaded': contentLoaded,
  };
}
