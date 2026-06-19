import '../../sources/models/source_models.dart';
import 'plugin_catalog.dart';

class PluginRuntimeChapter {
  const PluginRuntimeChapter({
    required this.id,
    required this.title,
    required this.index,
    this.updatedAt,
  });

  final String id;
  final String title;
  final int index;
  final DateTime? updatedAt;

  SourceChapter toSourceChapter(String storyId, {SourceContentKind? kind}) {
    return SourceChapter(
      id: id,
      storyId: storyId,
      title: title,
      index: index,
      contentKind: kind ?? SourceContentKind.text,
    );
  }
}

class PluginTextChapter {
  const PluginTextChapter({
    required this.id,
    required this.title,
    required this.index,
    required this.content,
  });

  final String id;
  final String title;
  final int index;
  final String content;
}

class PluginComicChapterImages {
  const PluginComicChapterImages({
    required this.id,
    required this.title,
    required this.index,
    required this.images,
  });

  final String id;
  final String title;
  final int index;
  final List<String> images;
}

extension PluginCatalogStorySource on PluginCatalogStory {
  SourceStory toSourceStory() {
    return SourceStory(
      id: storyId,
      sourceId: pluginId,
      title: title,
      author: author,
      description: description,
      contentType: contentType,
    );
  }
}
