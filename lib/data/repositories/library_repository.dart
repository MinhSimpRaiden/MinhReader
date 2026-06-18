import '../../features/library/models/story.dart';
import '../../features/reader/models/bookmark.dart';
import '../../features/reader/models/chapter.dart';
import '../../features/comic/models/comic_chapter.dart';
import '../../features/settings/models/reading_settings.dart';
import '../local/local_database.dart';

class LibraryRepository {
  LibraryRepository({LocalDatabase? database})
    : _database = database ?? LocalDatabase();

  final LocalDatabase _database;

  Future<LocalDatabaseSnapshot> load() => _database.read();

  Future<void> save({
    required List<Story> stories,
    required List<Chapter> chapters,
    required List<ComicChapter> comicChapters,
    required List<Bookmark> bookmarks,
    required ReadingSettings settings,
  }) {
    return _database.write(
      LocalDatabaseSnapshot(
        stories: stories,
        chapters: chapters,
        comicChapters: comicChapters,
        bookmarks: bookmarks,
        readingSettings: settings,
      ),
    );
  }
}
