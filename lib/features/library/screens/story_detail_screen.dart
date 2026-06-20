import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/source_formatters.dart';
import '../../comic/models/comic_chapter.dart';
import '../../comic/screens/comic_reader_screen.dart';
import '../../plugins/models/plugin_runtime_models.dart';
import '../../plugins/screens/plugin_network_comic_reader_screen.dart';
import '../../plugins/services/plugin_http_client.dart';
import '../../plugins/services/plugin_runtime_service.dart';
import '../../reader/models/bookmark.dart';
import '../../reader/models/chapter.dart';
import '../../reader/screens/reader_screen.dart';
import '../models/story.dart';
import '../providers/app_controller.dart';
import '../services/cover_service.dart';

class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({super.key, required this.storyId});

  final String storyId;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final _coverService = CoverService();
  final _pluginRuntimeService = PluginRuntimeService();
  String _contentQuery = '';
  bool _isLoadingRemoteChapter = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final story = controller.storyById(widget.storyId);
    final chapters = controller.chaptersFor(widget.storyId);
    final comicChapters = controller.comicChaptersFor(widget.storyId);
    final bookmarks = controller.bookmarksFor(widget.storyId);

    if (story == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy truyện')),
      );
    }
    final isComic = story.contentType == 'comic';
    final chapterCount = isComic ? comicChapters.length : chapters.length;
    final searchResults = isComic
        ? const <Chapter>[]
        : _searchChapters(chapters, _contentQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
        actions: [
          IconButton(
            tooltip: 'Xóa truyện',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 860;
                final info = _StoryInfoPanel(
                  story: story,
                  chapters: chapters,
                  onContinue: chapterCount == 0
                      ? null
                      : () => isComic
                            ? _openComicReader(
                                context,
                                story.lastReadChapterIndex.clamp(
                                  0,
                                  chapterCount - 1,
                                ),
                                scrollRatio: story.lastReadScrollRatio,
                              )
                            : _openReader(
                                context,
                                story.lastReadChapterIndex.clamp(
                                  0,
                                  chapterCount - 1,
                                ),
                                scrollRatio: story.lastReadScrollRatio,
                              ),
                  onReadFromStart: chapterCount == 0
                      ? null
                      : () => isComic
                            ? _openComicReader(context, 0)
                            : _openReader(context, 0),
                  onChangeCover: () => _changeCover(context),
                  onDeleteCover: story.coverPath == null
                      ? null
                      : () => _deleteCover(context),
                );
                final content = isComic
                    ? _ComicContentPanel(
                        chapters: comicChapters,
                        onOpenChapter: (chapterIndex) =>
                            _openComicReader(context, chapterIndex),
                      )
                    : _StoryContentPanel(
                        contentQuery: _contentQuery,
                        chapters: chapters,
                        bookmarks: bookmarks,
                        searchResults: searchResults,
                        isBusy: _isLoadingRemoteChapter,
                        onQueryChanged: (value) =>
                            setState(() => _contentQuery = value),
                        onOpenChapter: (chapterIndex, {scrollRatio}) =>
                            _openReader(
                              context,
                              chapterIndex,
                              scrollRatio: scrollRatio,
                            ),
                        onDeleteBookmark: (bookmarkId) =>
                            _deleteBookmark(context, bookmarkId),
                        resultPreview: _resultPreview,
                      );

                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [info, const SizedBox(height: 16), content],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 340,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [info],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                        children: [content],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Chapter> _searchChapters(List<Chapter> chapters, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return const [];
    return chapters.where((chapter) {
      return chapter.title.toLowerCase().contains(cleanQuery) ||
          chapter.content.toLowerCase().contains(cleanQuery);
    }).toList();
  }

  String _resultPreview(Chapter chapter, String query) {
    final cleanQuery = query.trim().toLowerCase();
    final lowerContent = chapter.content.toLowerCase();
    final index = lowerContent.indexOf(cleanQuery);
    if (index == -1) return 'Tìm thấy trong tiêu đề chương';
    final start = (index - 45).clamp(0, chapter.content.length);
    final end = (index + cleanQuery.length + 75).clamp(
      0,
      chapter.content.length,
    );
    final prefix = start > 0 ? '...' : '';
    final suffix = end < chapter.content.length ? '...' : '';
    return '$prefix${chapter.content.substring(start, end).replaceAll('\n', ' ')}$suffix';
  }

  Future<void> _openReader(
    BuildContext context,
    int chapterIndex, {
    double? scrollRatio,
  }) async {
    if (_isLoadingRemoteChapter) return;
    final controller = AppScope.of(context);
    final chapters = controller.chaptersFor(widget.storyId);
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return;
    final chapter = chapters[chapterIndex];
    if (chapter.isRemote && !chapter.contentLoaded) {
      final pluginId = chapter.pluginId;
      final remoteChapterId = chapter.remoteChapterId;
      if (pluginId == null || remoteChapterId == null) {
        _showPluginUnavailable(context);
        return;
      }
      setState(() => _isLoadingRemoteChapter = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải nội dung chương...')),
      );
      try {
        final textChapter = await _pluginRuntimeService.getTextChapterContent(
          pluginId,
          remoteChapterId,
        );
        if (textChapter.content.trim().isEmpty) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chương chưa có nội dung')),
          );
          return;
        }
        await controller.cacheRemoteChapterContent(
          storyId: widget.storyId,
          chapterId: chapter.id,
          content: textChapter.content,
        );
      } on PluginHttpException catch (error) {
        if (!context.mounted) return;
        if (error.message.contains('Không tìm thấy plugin') ||
            error.message.contains('chưa được bật')) {
          _showPluginUnavailable(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tải nội dung chương')),
          );
        }
        return;
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải nội dung chương')),
        );
        return;
      } finally {
        if (mounted) setState(() => _isLoadingRemoteChapter = false);
      }
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          storyId: widget.storyId,
          initialChapterIndex: chapterIndex,
          initialScrollRatio: scrollRatio,
        ),
      ),
    );
  }

  void _openComicReader(
    BuildContext context,
    int chapterIndex, {
    double? scrollRatio,
  }) {
    final controller = AppScope.of(context);
    final story = controller.storyById(widget.storyId);
    final chapters = controller.comicChaptersFor(widget.storyId);
    if (story?.isPluginRemote == true && chapters.isNotEmpty) {
      final pluginId = story!.pluginId;
      if (pluginId == null) {
        _showPluginUnavailable(context);
        return;
      }
      final runtimeChapters = [
        for (final chapter in chapters)
          if (chapter.remoteChapterId != null)
            PluginRuntimeChapter(
              id: chapter.remoteChapterId!,
              title: chapter.title,
              index: chapter.index,
            ),
      ];
      if (runtimeChapters.isEmpty) {
        _showPluginUnavailable(context);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PluginNetworkComicReaderScreen(
            pluginId: pluginId,
            storyId: story.remoteStoryId ?? story.id,
            storyTitle: story.title,
            chapters: runtimeChapters,
            initialChapterIndex: chapterIndex,
            runtimeService: _pluginRuntimeService,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComicReaderScreen(
          storyId: widget.storyId,
          initialChapterIndex: chapterIndex,
          initialScrollRatio: scrollRatio ?? 0,
        ),
      ),
    );
  }

  void _showPluginUnavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Plugin nguồn không còn khả dụng. Vui lòng bật hoặc cài lại plugin.',
        ),
      ),
    );
  }

  Future<void> _deleteBookmark(BuildContext context, String bookmarkId) async {
    await AppScope.of(context).deleteBookmark(bookmarkId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã xóa đánh dấu')));
  }

  Future<void> _changeCover(BuildContext context) async {
    try {
      final coverPath = await _coverService.pickAndSaveCover(widget.storyId);
      if (coverPath == null || !context.mounted) return;
      await AppScope.of(
        context,
      ).updateStoryCover(storyId: widget.storyId, coverPath: coverPath);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh bìa')));
    } on CoverException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể đọc ảnh bìa')));
    }
  }

  Future<void> _deleteCover(BuildContext context) async {
    try {
      await AppScope.of(
        context,
      ).updateStoryCover(storyId: widget.storyId, coverPath: null);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh bìa')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không thể đọc ảnh bìa')));
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa truyện'),
        content: const Text(
          'Truyện và toàn bộ chương sẽ bị xóa khỏi thư viện.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa truyện'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await AppScope.of(context).deleteStory(widget.storyId);
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa truyện. Vui lòng thử lại.'),
        ),
      );
    }
  }
}

class _StoryInfoPanel extends StatelessWidget {
  const _StoryInfoPanel({
    required this.story,
    required this.chapters,
    required this.onContinue,
    required this.onReadFromStart,
    required this.onChangeCover,
    required this.onDeleteCover,
  });

  final Story story;
  final List<Chapter> chapters;
  final VoidCallback? onContinue;
  final VoidCallback? onReadFromStart;
  final VoidCallback onChangeCover;
  final VoidCallback? onDeleteCover;

  @override
  Widget build(BuildContext context) {
    final progress = _progress(story);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _DetailCover(story: story)),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onChangeCover,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Đổi ảnh bìa'),
                  ),
                  TextButton.icon(
                    onPressed: onDeleteCover,
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Xóa ảnh bìa'),
                  ),
                ],
              ),
            ),
            Center(
              child: Text(
                story.coverPath == null ? 'Chưa có ảnh bìa' : 'Ảnh bìa',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Tác giả: ${story.author}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(formatSourceType(story.sourceType))),
                if (story.isPluginRemote) const Chip(label: Text('Online')),
                Chip(label: Text('${story.chapterCount} chương')),
                Chip(label: Text('${(progress * 100).round()}%')),
              ],
            ),
            if (story.description != null &&
                story.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(story.description!),
            ],
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: progress, minHeight: 7),
            ),
            const SizedBox(height: 12),
            Text('Đọc gần nhất: ${formatVietnameseDateTime(story.lastReadAt)}'),
            Text('Chương đang đọc: ${story.lastReadChapterIndex + 1}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Đọc tiếp'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReadFromStart,
                icon: const Icon(Icons.first_page),
                label: const Text('Đọc từ đầu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _progress(Story story) {
    if (story.chapterCount <= 0 || story.lastReadAt == null) return 0;
    return ((story.lastReadChapterIndex + 1) / story.chapterCount).clamp(
      0.0,
      1.0,
    );
  }
}

class _StoryContentPanel extends StatelessWidget {
  const _StoryContentPanel({
    required this.contentQuery,
    required this.chapters,
    required this.bookmarks,
    required this.searchResults,
    required this.isBusy,
    required this.onQueryChanged,
    required this.onOpenChapter,
    required this.onDeleteBookmark,
    required this.resultPreview,
  });

  final String contentQuery;
  final List<Chapter> chapters;
  final List<Bookmark> bookmarks;
  final List<Chapter> searchResults;
  final bool isBusy;
  final ValueChanged<String> onQueryChanged;
  final void Function(int chapterIndex, {double? scrollRatio}) onOpenChapter;
  final ValueChanged<String> onDeleteBookmark;
  final String Function(Chapter chapter, String query) resultPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Tìm trong truyện',
          ),
          onChanged: onQueryChanged,
        ),
        if (contentQuery.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionTitle(
            searchResults.isEmpty
                ? 'Không tìm thấy kết quả'
                : '${searchResults.length} chương có kết quả',
          ),
          ...searchResults.map((chapter) {
            return _SimpleTile(
              icon: Icons.search,
              title: chapter.title,
              subtitle: resultPreview(chapter, contentQuery),
              onTap: () => onOpenChapter(chapter.index),
            );
          }),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('Danh sách đánh dấu'),
        if (bookmarks.isEmpty)
          const Text('Chưa có đánh dấu nào')
        else
          ...bookmarks.map((bookmark) {
            return _SimpleTile(
              icon: Icons.bookmark,
              title: bookmark.chapterTitle,
              subtitle: [
                if (bookmark.note != null && bookmark.note!.trim().isNotEmpty)
                  'Ghi chú: ${bookmark.note}',
                'Ngày tạo: ${formatVietnameseDateTime(bookmark.createdAt)}',
              ].join('\n'),
              trailing: IconButton(
                tooltip: 'Xóa đánh dấu',
                onPressed: () => onDeleteBookmark(bookmark.id),
                icon: const Icon(Icons.delete_outline),
              ),
              onTap: () => onOpenChapter(
                bookmark.chapterIndex,
                scrollRatio: bookmark.scrollRatio,
              ),
            );
          }),
        const SizedBox(height: 24),
        const _SectionTitle('Danh sách chương'),
        ...chapters.map((chapter) {
          return _SimpleTile(
            icon: chapter.isRead
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            title: chapter.title,
            subtitle: chapter.isRemote && !chapter.contentLoaded
                ? 'Online - tải khi đọc'
                : '${chapter.wordCount} từ',
            onTap: isBusy ? null : () => onOpenChapter(chapter.index),
          );
        }),
      ],
    );
  }
}

class _ComicContentPanel extends StatelessWidget {
  const _ComicContentPanel({
    required this.chapters,
    required this.onOpenChapter,
  });

  final List<ComicChapter> chapters;
  final ValueChanged<int> onOpenChapter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Danh sách chương'),
        if (chapters.isEmpty)
          const Text('Chưa có chương truyện tranh')
        else
          ...chapters.map((chapter) {
            return _SimpleTile(
              icon: chapter.isRead
                  ? Icons.check_circle
                  : Icons.photo_library_outlined,
              title: chapter.title,
              subtitle: '${chapter.imagePaths.length} ảnh',
              onTap: () => onOpenChapter(chapter.index),
            );
          }),
      ],
    );
  }
}

class _DetailCover extends StatelessWidget {
  const _DetailCover({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final path = story.coverPath;
    final child = path != null && File(path).existsSync()
        ? Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _CoverPlaceholder(story: story),
          )
        : story.coverUrl != null && story.coverUrl!.trim().isNotEmpty
        ? Image.network(
            story.coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _CoverPlaceholder(story: story),
          )
        : _CoverPlaceholder(story: story);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 150, height: 214, child: child),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final initial = story.title.trim().isEmpty
        ? '?'
        : story.title.trim().substring(0, 1).toUpperCase();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              initial,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SimpleTile extends StatelessWidget {
  const _SimpleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
