import 'package:flutter/material.dart';

import '../../library/providers/app_controller.dart';
import '../../library/screens/story_detail_screen.dart';
import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import '../models/plugin_runtime_models.dart';
import '../services/plugin_http_client.dart';
import '../services/plugin_library_import_service.dart';
import '../services/plugin_runtime_service.dart';
import 'plugin_network_comic_reader_screen.dart';
import 'plugin_online_reader_screen.dart';

class PluginStoryDetailScreen extends StatefulWidget {
  const PluginStoryDetailScreen({
    super.key,
    required this.plugin,
    required this.story,
    this.runtimeService,
  });

  final PluginManifest plugin;
  final PluginCatalogStory story;
  final PluginRuntimeService? runtimeService;

  @override
  State<PluginStoryDetailScreen> createState() =>
      _PluginStoryDetailScreenState();
}

class _PluginStoryDetailScreenState extends State<PluginStoryDetailScreen> {
  late final PluginRuntimeService _runtimeService;
  final _importService = PluginLibraryImportService();
  PluginCatalogStory? _detail;
  List<PluginRuntimeChapter> _chapters = const [];
  bool _isLoading = true;
  bool _isBusy = false;

  PluginCatalogStory get _story => _detail ?? widget.story;

  @override
  void initState() {
    super.initState();
    _runtimeService = widget.runtimeService ?? PluginRuntimeService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      PluginCatalogStory detail = widget.story;
      if (widget.plugin.features.detail) {
        detail = await _runtimeService.getStoryDetail(
          widget.plugin.id,
          widget.story.storyId,
        );
      }
      final chapters = widget.plugin.features.chapters
          ? await _runtimeService.getChapterList(
              widget.plugin.id,
              widget.story.storyId,
            )
          : <PluginRuntimeChapter>[];
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _chapters = chapters;
        _isLoading = false;
      });
    } on PluginHttpException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Không thể tải thông tin truyện từ plugin');
    }
  }

  Future<void> _openChapter(PluginRuntimeChapter chapter) async {
    setState(() => _isBusy = true);
    try {
      if (_story.contentType == 'comic') {
        if (!widget.plugin.features.readComic ||
            (widget.plugin.endpoints['chapterImages'] ?? '').trim().isEmpty) {
          _showMessage('Plugin thiếu endpoint chapterImages');
          return;
        }
        final initialChapterIndex = _chapters.indexWhere(
          (item) => item.id == chapter.id,
        );
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PluginNetworkComicReaderScreen(
              pluginId: widget.plugin.id,
              storyId: widget.story.storyId,
              storyTitle: _story.title,
              chapters: _chapters,
              initialChapterIndex: initialChapterIndex < 0
                  ? chapter.index
                  : initialChapterIndex,
              runtimeService: _runtimeService,
            ),
          ),
        );
        return;
      }
      final textChapter = await _runtimeService.getTextChapterContent(
        widget.plugin.id,
        chapter.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PluginOnlineReaderScreen(
            title: textChapter.title,
            content: textChapter.content,
          ),
        ),
      );
    } on PluginHttpException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể đọc chương từ plugin');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _addToLibrary() async {
    final controller = AppScope.of(context);
    final existing = controller.storyByPluginRemoteId(
      pluginId: widget.plugin.id,
      remoteStoryId: _story.storyId,
    );
    if (existing != null) {
      _openLocalStory(existing.id);
      return;
    }
    if (_chapters.isEmpty) {
      _showMessage('Chưa có danh sách chương để thêm vào thư viện');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final draft = _importService.buildDraft(
        pluginId: widget.plugin.id,
        story: _story,
        chapters: _chapters,
      );
      final savedStory = draft.isComic
          ? await controller.addPluginComicStory(
              draft.story,
              draft.comicChapters,
            )
          : await controller.addPluginTextStory(draft.story, draft.chapters);
      if (!mounted) return;
      _showMessage('Đã thêm vào thư viện');
      _openLocalStory(savedStory.id);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể thêm vào thư viện');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _openLocalStory(String storyId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoryDetailScreen(storyId: storyId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final story = _story;
    final isComic = story.contentType == 'comic';
    final localStory = controller.storyByPluginRemoteId(
      pluginId: widget.plugin.id,
      remoteStoryId: story.storyId,
    );
    return Scaffold(
      appBar: AppBar(title: Text(story.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 96,
                            height: 132,
                            child:
                                story.coverUrl == null ||
                                    story.coverUrl!.isEmpty
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.menu_book,
                                      size: 42,
                                    ),
                                  )
                                : Image.network(
                                    story.coverUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                              size: 42,
                                            ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  story.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text('Tác giả: ${story.author}'),
                                Text(isComic ? 'Truyện tranh' : 'Truyện chữ'),
                                if (story.status != null)
                                  Text('Trạng thái: ${story.status}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(story.description),
                      const SizedBox(height: 18),
                      if (localStory == null)
                        FilledButton.icon(
                          onPressed:
                              _isBusy || _isLoading || _chapters.isEmpty
                              ? null
                              : _addToLibrary,
                          icon: const Icon(Icons.library_add_outlined),
                          label: const Text('Thêm vào thư viện'),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () => _openLocalStory(localStory.id),
                          icon: const Icon(Icons.library_books_outlined),
                          label: const Text('Mở trong thư viện'),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        localStory == null
                            ? 'Khi thêm vào thư viện, app chỉ lưu metadata và danh sách chương. Nội dung chương sẽ tải khi đọc.'
                            : 'Đã có trong thư viện',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Danh sách chương',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_chapters.isEmpty)
                        const Text('Chưa có danh sách chương')
                      else
                        ..._chapters.map(
                          (chapter) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              tileColor: Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              leading: Icon(
                                isComic
                                    ? Icons.image_outlined
                                    : Icons.article_outlined,
                              ),
                              title: Text(chapter.title),
                              subtitle: Text('Chương ${chapter.index + 1}'),
                              enabled: !_isBusy,
                              onTap: () => _openChapter(chapter),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
