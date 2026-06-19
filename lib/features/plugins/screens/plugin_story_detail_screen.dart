import 'package:flutter/material.dart';

import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import '../models/plugin_runtime_models.dart';
import '../services/plugin_http_client.dart';
import '../services/plugin_runtime_service.dart';
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
        await _runtimeService.getComicChapterImages(
          widget.plugin.id,
          chapter.id,
        );
        if (!mounted) return;
        _showMessage('Đọc ảnh online sẽ được hỗ trợ ở bước tiếp theo.');
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

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final isComic = story.contentType == 'comic';
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
                      FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('Thêm vào thư viện'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Phase này ưu tiên đọc online và cache metadata; thêm truyện api_json vào thư viện local sẽ hoàn thiện sau.',
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
