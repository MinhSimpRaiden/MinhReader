import 'package:flutter/material.dart';

import '../../../data/repositories/library_repository.dart';
import '../../comic/models/comic_chapter.dart';
import '../../comic/services/comic_storage_service.dart';
import '../../reader/models/bookmark.dart';
import '../../reader/models/chapter.dart';
import '../../settings/models/reading_settings.dart';
import '../models/story.dart';
import '../services/cover_service.dart';

class AppController extends ChangeNotifier {
  AppController(this._repository);

  final LibraryRepository _repository;
  final CoverService _coverService = CoverService();
  final ComicStorageService _comicStorageService = ComicStorageService();

  bool _isLoading = true;
  String? _error;
  List<Story> _stories = [];
  List<Chapter> _chapters = [];
  List<ComicChapter> _comicChapters = [];
  List<Bookmark> _bookmarks = [];
  ReadingSettings _settings = ReadingSettings.defaults;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Story> get stories => List.unmodifiable(_stories);
  ReadingSettings get settings => _settings;

  Future<void> load() async {
    try {
      _isLoading = true;
      notifyListeners();
      final snapshot = await _repository.load();
      _stories = snapshot.stories
        ..sort((a, b) {
          final aTime = a.lastReadAt ?? a.updatedAt;
          final bTime = b.lastReadAt ?? b.updatedAt;
          return bTime.compareTo(aTime);
        });
      _chapters = snapshot.chapters;
      _comicChapters = snapshot.comicChapters;
      _bookmarks = snapshot.bookmarks;
      _settings = snapshot.readingSettings;
      _error = snapshot.readWarning;
    } catch (_) {
      _error = 'Không thể tải dữ liệu. App sẽ mở với dữ liệu mặc định.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Chapter> chaptersFor(String storyId) {
    final result =
        _chapters.where((chapter) => chapter.storyId == storyId).toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  List<Bookmark> bookmarksFor(String storyId) {
    final result =
        _bookmarks.where((bookmark) => bookmark.storyId == storyId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  List<ComicChapter> comicChaptersFor(String storyId) {
    final result =
        _comicChapters.where((chapter) => chapter.storyId == storyId).toList()
          ..sort((a, b) => a.index.compareTo(b.index));
    return result;
  }

  Bookmark? bookmarkNear({
    required String storyId,
    required int chapterIndex,
    required double scrollRatio,
  }) {
    for (final bookmark in _bookmarks) {
      final samePlace =
          bookmark.storyId == storyId &&
          bookmark.chapterIndex == chapterIndex &&
          (bookmark.scrollRatio - scrollRatio).abs() <= 0.03;
      if (samePlace) return bookmark;
    }
    return null;
  }

  Story? storyById(String storyId) {
    for (final story in _stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }

  Story? storyByPluginRemoteId({
    required String pluginId,
    required String remoteStoryId,
  }) {
    for (final story in _stories) {
      if (story.pluginId == pluginId && story.remoteStoryId == remoteStoryId) {
        return story;
      }
    }
    return null;
  }

  Future<Story> addStory(Story story, List<Chapter> chapters) async {
    final previousStories = _stories;
    final previousChapters = _chapters;
    final savedStory = story.copyWith(title: _uniqueTitle(story.title));

    _stories = [savedStory, ..._stories];
    _chapters = [..._chapters, ...chapters];
    try {
      await _persist();
      _error = null;
      notifyListeners();
      return savedStory;
    } catch (_) {
      _stories = previousStories;
      _chapters = previousChapters;
      _error = 'Không thể lưu truyện. Vui lòng thử lại.';
      notifyListeners();
      rethrow;
    }
  }

  Future<Story> addPluginTextStory(Story story, List<Chapter> chapters) async {
    final pluginId = story.pluginId;
    final remoteStoryId = story.remoteStoryId;
    if (pluginId != null && remoteStoryId != null) {
      final existing = storyByPluginRemoteId(
        pluginId: pluginId,
        remoteStoryId: remoteStoryId,
      );
      if (existing != null) return existing;
    }
    return addStory(story, chapters);
  }

  Future<Story> addComicStory(Story story, List<ComicChapter> chapters) async {
    final previousStories = _stories;
    final previousComicChapters = _comicChapters;
    final savedStory = story.copyWith(title: _uniqueTitle(story.title));

    _stories = [savedStory, ..._stories];
    _comicChapters = [..._comicChapters, ...chapters];
    try {
      await _persist();
      _error = null;
      notifyListeners();
      return savedStory;
    } catch (_) {
      _stories = previousStories;
      _comicChapters = previousComicChapters;
      _error = 'Không thể lưu truyện tranh. Vui lòng thử lại.';
      notifyListeners();
      rethrow;
    }
  }

  Future<Story> addPluginComicStory(
    Story story,
    List<ComicChapter> chapters,
  ) async {
    final pluginId = story.pluginId;
    final remoteStoryId = story.remoteStoryId;
    if (pluginId != null && remoteStoryId != null) {
      final existing = storyByPluginRemoteId(
        pluginId: pluginId,
        remoteStoryId: remoteStoryId,
      );
      if (existing != null) return existing;
    }
    return addComicStory(story, chapters);
  }

  Future<void> cacheRemoteChapterContent({
    required String storyId,
    required String chapterId,
    required String content,
  }) async {
    final previousChapters = _chapters;
    final wordCount = content
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .length;
    var changed = false;
    _chapters = _chapters.map((chapter) {
      if (chapter.storyId == storyId && chapter.id == chapterId) {
        changed = true;
        return chapter.copyWith(
          content: content,
          wordCount: wordCount,
          contentLoaded: true,
        );
      }
      return chapter;
    }).toList();
    if (!changed) return;
    try {
      await _persist();
      _error = null;
      notifyListeners();
    } catch (_) {
      _chapters = previousChapters;
      _error = 'Không thể lưu nội dung chương đã tải.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteStory(String storyId) async {
    final previousStories = _stories;
    final previousChapters = _chapters;
    final previousComicChapters = _comicChapters;
    final previousBookmarks = _bookmarks;
    final deletedStory = storyById(storyId);
    final deletedCoverPath = deletedStory?.coverPath;
    _stories = _stories.where((story) => story.id != storyId).toList();
    _chapters = _chapters
        .where((chapter) => chapter.storyId != storyId)
        .toList();
    _comicChapters = _comicChapters
        .where((chapter) => chapter.storyId != storyId)
        .toList();
    _bookmarks = _bookmarks
        .where((bookmark) => bookmark.storyId != storyId)
        .toList();
    try {
      await _persist();
      if (!_isCoverUsed(deletedCoverPath)) {
        await _coverService.deleteManagedCover(deletedCoverPath);
      }
      if (deletedStory?.contentType == 'comic') {
        await _comicStorageService.deleteStoryDirectory(storyId);
      }
      _error = null;
      notifyListeners();
    } catch (_) {
      _stories = previousStories;
      _chapters = previousChapters;
      _comicChapters = previousComicChapters;
      _bookmarks = previousBookmarks;
      _error = 'Không thể xóa truyện. Dữ liệu cũ vẫn được giữ nguyên.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateStoryCover({
    required String storyId,
    required String? coverPath,
  }) async {
    final previousStories = _stories;
    final oldCoverPath = storyById(storyId)?.coverPath;
    final now = DateTime.now();

    _stories = _stories.map((story) {
      if (story.id != storyId) return story;
      return story.copyWith(
        coverPath: coverPath,
        clearCoverPath: coverPath == null,
        updatedAt: now,
      );
    }).toList();

    try {
      await _persist();
      if (oldCoverPath != coverPath && !_isCoverUsed(oldCoverPath)) {
        await _coverService.deleteManagedCover(oldCoverPath);
      }
      _error = null;
      notifyListeners();
    } catch (_) {
      _stories = previousStories;
      _error = 'Không thể cập nhật ảnh bìa.';
      notifyListeners();
      rethrow;
    }
  }

  Future<Bookmark> saveBookmark({
    required String storyId,
    required int chapterIndex,
    required String chapterTitle,
    required double scrollRatio,
    String? note,
    String? bookmarkId,
  }) async {
    final previousBookmarks = _bookmarks;
    final now = DateTime.now();
    final cleanNote = note?.trim();
    final existing = bookmarkId == null
        ? bookmarkNear(
            storyId: storyId,
            chapterIndex: chapterIndex,
            scrollRatio: scrollRatio,
          )
        : _bookmarkById(bookmarkId);
    final bookmark = existing == null
        ? Bookmark(
            id: now.microsecondsSinceEpoch.toString(),
            storyId: storyId,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            scrollRatio: scrollRatio.clamp(0.0, 1.0),
            note: cleanNote?.isEmpty == true ? null : cleanNote,
            createdAt: now,
          )
        : existing.copyWith(
            chapterTitle: chapterTitle,
            scrollRatio: scrollRatio.clamp(0.0, 1.0),
            note: cleanNote?.isEmpty == true ? null : cleanNote,
          );

    _bookmarks = [
      bookmark,
      ..._bookmarks.where((item) => item.id != bookmark.id),
    ];
    try {
      await _persist();
      _error = null;
      notifyListeners();
      return bookmark;
    } catch (_) {
      _bookmarks = previousBookmarks;
      _error = 'Không thể lưu đánh dấu.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBookmark(String bookmarkId) async {
    final previousBookmarks = _bookmarks;
    _bookmarks = _bookmarks
        .where((bookmark) => bookmark.id != bookmarkId)
        .toList();
    try {
      await _persist();
      _error = null;
      notifyListeners();
    } catch (_) {
      _bookmarks = previousBookmarks;
      _error = 'Không thể xóa đánh dấu.';
      notifyListeners();
      rethrow;
    }
  }

  Bookmark? _bookmarkById(String bookmarkId) {
    for (final bookmark in _bookmarks) {
      if (bookmark.id == bookmarkId) return bookmark;
    }
    return null;
  }

  Future<void> updateReadingProgress({
    required String storyId,
    required int chapterIndex,
    double? scrollRatio,
    bool markRead = true,
  }) async {
    final now = DateTime.now();
    final previousStories = _stories;
    final previousChapters = _chapters;
    _stories = _stories.map((story) {
      if (story.id != storyId) return story;
      return story.copyWith(
        lastReadAt: now,
        lastReadChapterIndex: chapterIndex,
        lastReadScrollRatio: (scrollRatio ?? story.lastReadScrollRatio).clamp(
          0,
          1,
        ),
        updatedAt: now,
      );
    }).toList();
    if (markRead) {
      _chapters = _chapters.map((chapter) {
        if (chapter.storyId == storyId && chapter.index == chapterIndex) {
          return chapter.copyWith(isRead: true);
        }
        return chapter;
      }).toList();
    }
    try {
      await _persist();
      _error = null;
      notifyListeners();
    } catch (_) {
      _stories = previousStories;
      _chapters = previousChapters;
      _error = 'Không thể lưu tiến độ đọc.';
      notifyListeners();
    }
  }

  Future<void> updateComicReadingProgress({
    required String storyId,
    required int chapterIndex,
    double? scrollRatio,
    bool markRead = true,
  }) async {
    final now = DateTime.now();
    final previousStories = _stories;
    final previousComicChapters = _comicChapters;
    _stories = _stories.map((story) {
      if (story.id != storyId) return story;
      return story.copyWith(
        lastReadAt: now,
        lastReadChapterIndex: chapterIndex,
        lastReadScrollRatio: (scrollRatio ?? story.lastReadScrollRatio).clamp(
          0,
          1,
        ),
        updatedAt: now,
      );
    }).toList();
    if (markRead) {
      _comicChapters = _comicChapters.map((chapter) {
        if (chapter.storyId == storyId && chapter.index == chapterIndex) {
          return chapter.copyWith(isRead: true);
        }
        return chapter;
      }).toList();
    }
    try {
      await _persist();
      _error = null;
      notifyListeners();
    } catch (_) {
      _stories = previousStories;
      _comicChapters = previousComicChapters;
      _error = 'Không thể lưu tiến độ đọc truyện tranh.';
      notifyListeners();
    }
  }

  Future<void> updateSettings(ReadingSettings settings) async {
    final previousSettings = _settings;
    _settings = settings;
    try {
      await _persist();
      _error = null;
      notifyListeners();
    } catch (_) {
      _settings = previousSettings;
      _error = 'Không thể lưu cài đặt đọc.';
      notifyListeners();
    }
  }

  Future<void> resetSettings() => updateSettings(ReadingSettings.defaults);

  String _uniqueTitle(String title) {
    final existingTitles = _stories
        .map((story) => story.title.trim().toLowerCase())
        .toSet();
    final base = title.trim().isEmpty ? 'Truyện chưa đặt tên' : title.trim();
    if (!existingTitles.contains(base.toLowerCase())) return base;

    var index = 2;
    while (existingTitles.contains('$base ($index)'.toLowerCase())) {
      index++;
    }
    return '$base ($index)';
  }

  bool _isCoverUsed(String? path) {
    if (path == null) return false;
    return _stories.any((story) => story.coverPath == path);
  }

  Future<void> _persist() {
    return _repository.save(
      stories: _stories,
      chapters: _chapters,
      comicChapters: _comicChapters,
      bookmarks: _bookmarks,
      settings: _settings,
    );
  }
}

class AppScope extends StatefulWidget {
  const AppScope({super.key, required this.controller, required this.child});

  final AppController controller;
  final Widget child;

  static AppController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppInheritedNotifier>();
    assert(scope != null, 'Không tìm thấy AppScope trong widget tree.');
    return scope!.notifier!;
  }

  static AppController watch(BuildContext context) => of(context);

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return _AppInheritedNotifier(
      notifier: widget.controller,
      child: widget.child,
    );
  }
}

class _AppInheritedNotifier extends InheritedNotifier<AppController> {
  const _AppInheritedNotifier({required super.notifier, required super.child});
}
