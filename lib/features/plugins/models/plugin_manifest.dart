import '../../sources/models/source_models.dart';

class PluginManifest {
  const PluginManifest({
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
    this.baseUrl,
    this.homepage,
    this.isAdultContent = false,
    this.endpoints = const {},
    this.headers = const {},
    this.rateLimit,
    this.attribution,
    this.isEnabled = true,
  });

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
  final bool isAdultContent;
  final Map<String, String> endpoints;
  final Map<String, String> headers;
  final int? rateLimit;
  final String? attribution;
  final bool isEnabled;
  final List<PluginStory> stories;

  PluginManifest copyWith({bool? isEnabled}) {
    return PluginManifest(
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
      isAdultContent: isAdultContent,
      endpoints: endpoints,
      headers: headers,
      rateLimit: rateLimit,
      attribution: attribution,
      isEnabled: isEnabled ?? this.isEnabled,
      stories: stories,
    );
  }

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
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
      isAdultContent: json['isAdultContent'] as bool? ?? false,
      endpoints: _stringMap(json['endpoints']),
      headers: _stringMap(json['headers']),
      rateLimit: json['rateLimit'] as int?,
      attribution: json['attribution'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      stories: (json['stories'] as List<dynamic>? ?? [])
          .map((item) => PluginStory.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
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
    'isAdultContent': isAdultContent,
    'endpoints': endpoints,
    'headers': headers,
    'rateLimit': rateLimit,
    'attribution': attribution,
    'isEnabled': isEnabled,
    'stories': stories.map((story) => story.toJson()).toList(),
  };

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry('$key', '$item'));
  }
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
