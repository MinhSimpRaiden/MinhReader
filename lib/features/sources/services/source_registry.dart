import 'local_file_sources.dart';
import 'mock_comic_source.dart';
import 'mock_public_domain_source.dart';
import 'story_source.dart';

class SourceRegistry {
  SourceRegistry({List<StorySource>? sources})
    : sources =
          sources ??
          const [
            LocalTxtSource(),
            LocalEpubSource(),
            MockPublicDomainSource(),
            MockComicSource(),
          ];

  final List<StorySource> sources;

  StorySource? byId(String sourceId) {
    for (final source in sources) {
      if (source.id == sourceId) return source;
    }
    return null;
  }
}
