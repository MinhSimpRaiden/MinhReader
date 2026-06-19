class PluginCatalogStory {
  const PluginCatalogStory({
    required this.pluginId,
    required this.storyId,
    required this.title,
    required this.author,
    required this.description,
    required this.contentType,
    this.coverUrl,
    this.status,
    this.genres = const [],
    this.updatedAt,
  });

  final String pluginId;
  final String storyId;
  final String title;
  final String author;
  final String description;
  final String? coverUrl;
  final String contentType;
  final String? status;
  final List<String> genres;
  final DateTime? updatedAt;

  factory PluginCatalogStory.fromJson(Map<String, dynamic> json) {
    return PluginCatalogStory(
      pluginId: json['pluginId'] as String? ?? '',
      storyId: json['storyId'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? 'Không rõ',
      description: json['description'] as String? ?? '',
      coverUrl: json['coverUrl'] as String?,
      contentType: json['contentType'] as String? ?? 'text',
      status: json['status'] as String?,
      genres: (json['genres'] as List<dynamic>? ?? [])
          .map((item) => '$item')
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'pluginId': pluginId,
    'storyId': storyId,
    'title': title,
    'author': author,
    'description': description,
    'coverUrl': coverUrl,
    'contentType': contentType,
    'status': status,
    'genres': genres,
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

class PluginCatalogCacheEntry {
  const PluginCatalogCacheEntry({
    required this.pluginId,
    this.stories = const [],
    this.lastSyncAt,
    this.pageSynced = 0,
    this.hasNextPage = true,
  });

  final String pluginId;
  final List<PluginCatalogStory> stories;
  final DateTime? lastSyncAt;
  final int pageSynced;
  final bool hasNextPage;

  PluginCatalogCacheEntry copyWith({
    List<PluginCatalogStory>? stories,
    DateTime? lastSyncAt,
    int? pageSynced,
    bool? hasNextPage,
  }) {
    return PluginCatalogCacheEntry(
      pluginId: pluginId,
      stories: stories ?? this.stories,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      pageSynced: pageSynced ?? this.pageSynced,
      hasNextPage: hasNextPage ?? this.hasNextPage,
    );
  }

  factory PluginCatalogCacheEntry.fromJson(Map<String, dynamic> json) {
    return PluginCatalogCacheEntry(
      pluginId: json['pluginId'] as String? ?? '',
      stories: (json['stories'] as List<dynamic>? ?? [])
          .map(
            (item) => PluginCatalogStory.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      lastSyncAt: DateTime.tryParse(json['lastSyncAt'] as String? ?? ''),
      pageSynced: json['pageSynced'] as int? ?? 0,
      hasNextPage: json['hasNextPage'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'pluginId': pluginId,
    'stories': stories.map((story) => story.toJson()).toList(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'pageSynced': pageSynced,
    'hasNextPage': hasNextPage,
  };
}

class PluginCatalogSyncResult {
  const PluginCatalogSyncResult({
    required this.pluginId,
    required this.syncedCount,
    required this.totalCached,
    required this.pageSynced,
    required this.hasNextPage,
  });

  final String pluginId;
  final int syncedCount;
  final int totalCached;
  final int pageSynced;
  final bool hasNextPage;
}
