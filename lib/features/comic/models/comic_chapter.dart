class ComicChapter {
  const ComicChapter({
    required this.id,
    required this.storyId,
    required this.index,
    required this.title,
    required this.imagePaths,
    this.isRead = false,
    this.pluginId,
    this.remoteChapterId,
    this.isRemote = false,
    this.imageUrls = const [],
    this.contentLoaded = true,
  });

  final String id;
  final String storyId;
  final int index;
  final String title;
  final List<String> imagePaths;
  final bool isRead;
  final String? pluginId;
  final String? remoteChapterId;
  final bool isRemote;
  final List<String> imageUrls;
  final bool contentLoaded;

  ComicChapter copyWith({
    List<String>? imagePaths,
    bool? isRead,
    String? pluginId,
    String? remoteChapterId,
    bool? isRemote,
    List<String>? imageUrls,
    bool? contentLoaded,
  }) {
    return ComicChapter(
      id: id,
      storyId: storyId,
      index: index,
      title: title,
      imagePaths: imagePaths ?? this.imagePaths,
      isRead: isRead ?? this.isRead,
      pluginId: pluginId ?? this.pluginId,
      remoteChapterId: remoteChapterId ?? this.remoteChapterId,
      isRemote: isRemote ?? this.isRemote,
      imageUrls: imageUrls ?? this.imageUrls,
      contentLoaded: contentLoaded ?? this.contentLoaded,
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
      pluginId: json['pluginId'] as String?,
      remoteChapterId: json['remoteChapterId'] as String?,
      isRemote: json['isRemote'] as bool? ?? false,
      imageUrls: (json['imageUrls'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
      contentLoaded: json['contentLoaded'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'storyId': storyId,
    'index': index,
    'title': title,
    'imagePaths': imagePaths,
    'isRead': isRead,
    'pluginId': pluginId,
    'remoteChapterId': remoteChapterId,
    'isRemote': isRemote,
    'imageUrls': imageUrls,
    'contentLoaded': contentLoaded,
  };
}
