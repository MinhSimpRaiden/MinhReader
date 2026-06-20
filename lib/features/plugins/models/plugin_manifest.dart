import '../../sources/models/source_models.dart';

class PluginManifest {
  const PluginManifest({
    this.schemaVersion = 1,
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.contentType,
    required this.sourceType,
    required this.license,
    required this.language,
    required this.stories,
    this.features = const PluginFeatures(),
    this.pagination = const PluginPagination(),
    this.baseUrl,
    this.homepage,
    this.isAdultContent = false,
    this.endpoints = const {},
    this.headers = const {},
    this.rateLimit = const PluginRateLimit(),
    this.attribution,
    this.isEnabled = true,
    this.installUrl,
    this.sourceUrl,
  });

  final int schemaVersion;
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final String contentType;
  final String sourceType;
  final String? baseUrl;
  final String license;
  final String? homepage;
  final String language;
  final PluginFeatures features;
  final PluginPagination pagination;
  final bool isAdultContent;
  final Map<String, String> endpoints;
  final Map<String, String> headers;
  final PluginRateLimit rateLimit;
  final String? attribution;
  final bool isEnabled;
  final String? installUrl;
  final String? sourceUrl;
  final List<PluginStory> stories;

  PluginManifest copyWith({
    bool? isEnabled,
    String? installUrl,
    String? sourceUrl,
  }) {
    return PluginManifest(
      schemaVersion: schemaVersion,
      id: id,
      name: name,
      version: version,
      author: author,
      description: description,
      contentType: contentType,
      sourceType: sourceType,
      baseUrl: baseUrl,
      license: license,
      homepage: homepage,
      language: language,
      features: features,
      pagination: pagination,
      isAdultContent: isAdultContent,
      endpoints: endpoints,
      headers: headers,
      rateLimit: rateLimit,
      attribution: attribution,
      isEnabled: isEnabled ?? this.isEnabled,
      installUrl: installUrl ?? this.installUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      stories: stories,
    );
  }

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      schemaVersion: json['schemaVersion'] as int? ?? 1,
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'text',
      sourceType: json['sourceType'] as String? ?? 'static_json',
      baseUrl: json['baseUrl'] as String?,
      license: json['license'] as String? ?? '',
      homepage: json['homepage'] as String?,
      language: json['language'] as String? ?? 'vi',
      features: PluginFeatures.fromJson(json['features']),
      pagination: PluginPagination.fromJson(json['pagination']),
      isAdultContent: json['isAdultContent'] as bool? ?? false,
      endpoints: _stringMap(json['endpoints']),
      headers: _stringMap(json['headers']),
      rateLimit: PluginRateLimit.fromJson(json['rateLimit']),
      attribution: json['attribution'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      installUrl: json['installUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      stories: (json['stories'] as List<dynamic>? ?? [])
          .map((item) => PluginStory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'contentType': contentType,
    'sourceType': sourceType,
    'baseUrl': baseUrl,
    'license': license,
    'homepage': homepage,
    'language': language,
    'features': features.toJson(),
    'pagination': pagination.toJson(),
    'isAdultContent': isAdultContent,
    'endpoints': endpoints,
    'headers': headers,
    'rateLimit': rateLimit.toJson(),
    'attribution': attribution,
    'isEnabled': isEnabled,
    if (installUrl != null) 'installUrl': installUrl,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    'stories': stories.map((story) => story.toJson()).toList(),
  };

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry('$key', '$item'));
  }
}

class PluginFeatures {
  const PluginFeatures({
    this.catalog = false,
    this.search = false,
    this.latest = false,
    this.detail = false,
    this.chapters = false,
    this.readText = false,
    this.readComic = false,
  });

  final bool catalog;
  final bool search;
  final bool latest;
  final bool detail;
  final bool chapters;
  final bool readText;
  final bool readComic;

  factory PluginFeatures.fromJson(dynamic json) {
    if (json is! Map) return const PluginFeatures();
    return PluginFeatures(
      catalog: json['catalog'] as bool? ?? false,
      search: json['search'] as bool? ?? false,
      latest: json['latest'] as bool? ?? false,
      detail: json['detail'] as bool? ?? false,
      chapters: json['chapters'] as bool? ?? false,
      readText: json['readText'] as bool? ?? false,
      readComic: json['readComic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'catalog': catalog,
    'search': search,
    'latest': latest,
    'detail': detail,
    'chapters': chapters,
    'readText': readText,
    'readComic': readComic,
  };
}

class PluginPagination {
  const PluginPagination({
    this.type = 'page',
    this.startPage = 1,
    this.defaultLimit = 20,
    this.maxPagesPerSync = 5,
  });

  final String type;
  final int startPage;
  final int defaultLimit;
  final int maxPagesPerSync;

  factory PluginPagination.fromJson(dynamic json) {
    if (json is! Map) return const PluginPagination();
    return PluginPagination(
      type: json['type'] as String? ?? 'page',
      startPage: json['startPage'] as int? ?? 1,
      defaultLimit: json['defaultLimit'] as int? ?? 20,
      maxPagesPerSync: json['maxPagesPerSync'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'startPage': startPage,
    'defaultLimit': defaultLimit,
    'maxPagesPerSync': maxPagesPerSync,
  };
}

class PluginRateLimit {
  const PluginRateLimit({this.requestsPerMinute = 30});

  final int requestsPerMinute;

  factory PluginRateLimit.fromJson(dynamic json) {
    if (json is int) return PluginRateLimit(requestsPerMinute: json);
    if (json is! Map) return const PluginRateLimit();
    return PluginRateLimit(
      requestsPerMinute: json['requestsPerMinute'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() => {'requestsPerMinute': requestsPerMinute};
}

class PluginStory {
  const PluginStory({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.contentType,
    required this.chapters,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String contentType;
  final List<PluginChapter> chapters;

  SourceStory toSourceStory(String sourceId) {
    return SourceStory(
      id: id,
      sourceId: sourceId,
      title: title,
      author: author,
      description: description,
      contentType: contentType,
    );
  }

  factory PluginStory.fromJson(Map<String, dynamic> json) {
    return PluginStory(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'text',
      chapters: (json['chapters'] as List<dynamic>? ?? [])
          .map((item) => PluginChapter.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'description': description,
    'contentType': contentType,
    'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
  };
}

class PluginChapter {
  const PluginChapter({
    required this.id,
    required this.title,
    required this.index,
    required this.contentKind,
    this.content = '',
    this.imagePaths = const [],
  });

  final String id;
  final String title;
  final int index;
  final SourceContentKind contentKind;
  final String content;
  final List<String> imagePaths;

  SourceChapter toSourceChapter(String storyId) {
    return SourceChapter(
      id: id,
      storyId: storyId,
      title: title,
      index: index,
      contentKind: contentKind,
      imagePaths: imagePaths,
    );
  }

  factory PluginChapter.fromJson(Map<String, dynamic> json) {
    final kind = json['contentKind'] == 'images'
        ? SourceContentKind.images
        : SourceContentKind.text;
    return PluginChapter(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      index: json['index'] as int? ?? 0,
      contentKind: kind,
      content: json['content'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? [])
          .map((item) => item as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'index': index,
    'contentKind': contentKind == SourceContentKind.images ? 'images' : 'text',
    'content': content,
    'imagePaths': imagePaths,
  };
}
