import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/source_formatters.dart';
import '../../import/screens/import_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../sources/screens/sources_screen.dart';
import '../models/story.dart';
import '../providers/app_controller.dart';
import 'story_detail_screen.dart';

enum LibrarySortMode { recentRead, recentAdded, titleAz, chapterCount }

enum LibraryFilterMode { all, txt, epub, comic, demo, reading, finished }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  LibrarySortMode _sortMode = LibrarySortMode.recentRead;
  LibraryFilterMode _filterMode = LibraryFilterMode.all;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final stories = _visibleStories(controller.stories);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện'),
        actions: [
          IconButton(
            tooltip: 'Nguồn truyện',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SourcesScreen())),
            icon: const Icon(Icons.hub_outlined),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        if (controller.error != null) ...[
                          MaterialBanner(
                            content: Text(controller.error!),
                            leading: const Icon(Icons.warning_amber_outlined),
                            actions: [
                              TextButton(
                                onPressed: controller.load,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        _LibraryToolbar(
                          query: _query,
                          sortMode: _sortMode,
                          filterMode: _filterMode,
                          onQueryChanged: (value) =>
                              setState(() => _query = value),
                          onSortChanged: (value) =>
                              setState(() => _sortMode = value),
                          onFilterChanged: (value) =>
                              setState(() => _filterMode = value),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: controller.stories.isEmpty
                              ? _EmptyLibrary(onImport: _openImport)
                              : stories.isEmpty
                              ? const _NoLibraryResult()
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final wide = constraints.maxWidth >= 760;
                                    if (!wide) {
                                      return ListView.separated(
                                        itemCount: stories.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 12),
                                        itemBuilder: (context, index) {
                                          return _StoryCard(
                                            story: stories[index],
                                            compact: true,
                                          );
                                        },
                                      );
                                    }
                                    return GridView.builder(
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 2,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 2.55,
                                          ),
                                      itemCount: stories.length,
                                      itemBuilder: (context, index) {
                                        return _StoryCard(
                                          story: stories[index],
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openImport,
        icon: const Icon(Icons.upload_file),
        label: const Text('Nhập truyện'),
      ),
    );
  }

  List<Story> _visibleStories(List<Story> stories) {
    final query = _query.trim().toLowerCase();
    final filtered = stories.where((story) {
      final sourceLabel = formatSourceType(story.sourceType).toLowerCase();
      final matchesQuery =
          query.isEmpty ||
          story.title.toLowerCase().contains(query) ||
          story.author.toLowerCase().contains(query) ||
          sourceLabel.contains(query);
      if (!matchesQuery) return false;

      return switch (_filterMode) {
        LibraryFilterMode.all => true,
        LibraryFilterMode.txt => story.sourceType == 'local_txt',
        LibraryFilterMode.epub => story.sourceType == 'local_epub',
        LibraryFilterMode.comic => story.contentType == 'comic',
        LibraryFilterMode.demo => story.sourceType == 'public_domain_demo',
        LibraryFilterMode.reading =>
          story.lastReadAt != null || story.lastReadChapterIndex > 0,
        LibraryFilterMode.finished =>
          story.chapterCount > 0 &&
              story.lastReadAt != null &&
              story.lastReadChapterIndex >= story.chapterCount - 1,
      };
    }).toList();

    filtered.sort((a, b) {
      return switch (_sortMode) {
        LibrarySortMode.recentRead => (b.lastReadAt ?? b.updatedAt).compareTo(
          a.lastReadAt ?? a.updatedAt,
        ),
        LibrarySortMode.recentAdded => b.createdAt.compareTo(a.createdAt),
        LibrarySortMode.titleAz => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        LibrarySortMode.chapterCount => b.chapterCount.compareTo(
          a.chapterCount,
        ),
      };
    });
    return filtered;
  }

  Future<void> _openImport() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImportScreen()));
  }
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.query,
    required this.sortMode,
    required this.filterMode,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  final String query;
  final LibrarySortMode sortMode;
  final LibraryFilterMode filterMode;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<LibrarySortMode> onSortChanged;
  final ValueChanged<LibraryFilterMode> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm theo tên, tác giả hoặc loại nguồn',
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<LibrarySortMode>(
                initialValue: sortMode,
                decoration: const InputDecoration(labelText: 'Sắp xếp'),
                items: const [
                  DropdownMenuItem(
                    value: LibrarySortMode.recentRead,
                    child: Text('Mới đọc gần đây'),
                  ),
                  DropdownMenuItem(
                    value: LibrarySortMode.recentAdded,
                    child: Text('Mới thêm gần đây'),
                  ),
                  DropdownMenuItem(
                    value: LibrarySortMode.titleAz,
                    child: Text('Tên A-Z'),
                  ),
                  DropdownMenuItem(
                    value: LibrarySortMode.chapterCount,
                    child: Text('Nhiều chương nhất'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onSortChanged(value);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<LibraryFilterMode>(
                initialValue: filterMode,
                decoration: const InputDecoration(labelText: 'Lọc'),
                items: const [
                  DropdownMenuItem(
                    value: LibraryFilterMode.all,
                    child: Text('Tất cả'),
                  ),
                  DropdownMenuItem(
                    value: LibraryFilterMode.txt,
                    child: Text('TXT'),
                  ),
                  DropdownMenuItem(
                    value: LibraryFilterMode.epub,
                    child: Text('EPUB'),
                  ),
                  DropdownMenuItem(
                    value: LibraryFilterMode.comic,
                    child: Text('Truyện tranh'),
                  ),
                  DropdownMenuItem(
                    value: LibraryFilterMode.demo,
                    child: Text('Demo'),
                  ),
                  DropdownMenuItem(
                    value: LibraryFilterMode.reading,
                    child: Text('Đang đọc'),
                  ),
                  DropdownMenuItem(
                    value: LibraryFilterMode.finished,
                    child: Text('Đã đọc xong'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) onFilterChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.story, this.compact = false});

  final Story story;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final progress = _progress(story);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryDetailScreen(storyId: story.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(story: story),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            story.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniBadge(formatSourceType(story.sourceType)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _MetaText('${story.chapterCount} chương'),
                        _MetaText('Chương ${story.lastReadChapterIndex + 1}'),
                        _MetaText('${(progress * 100).round()}%'),
                        _MetaText(formatVietnameseDateTime(story.lastReadAt)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _progress(Story story) {
    if (story.chapterCount <= 0 || story.lastReadAt == null) return 0;
    final chapterProgress = (story.lastReadChapterIndex + 1).clamp(
      0,
      story.chapterCount,
    );
    return (chapterProgress / story.chapterCount).clamp(0.0, 1.0);
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.story});

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
        : _CoverPlaceholder(story: story);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: 76, height: 108, child: child),
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
              size: 30,
            ),
            const SizedBox(height: 5),
            Text(
              initial,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
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

class _MiniBadge extends StatelessWidget {
  const _MiniBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _NoLibraryResult extends StatelessWidget {
  const _NoLibraryResult();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Không tìm thấy truyện phù hợp'));
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_library_outlined,
              size: 76,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có truyện nào',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Hãy nhập TXT/EPUB hoặc thêm truyện từ nguồn demo để bắt đầu đọc',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Nhập truyện'),
            ),
          ],
        ),
      ),
    );
  }
}
