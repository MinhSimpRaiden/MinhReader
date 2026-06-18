import 'package:flutter/material.dart';

import '../../library/providers/app_controller.dart';
import '../../library/screens/story_detail_screen.dart';
import '../../plugins/models/plugin_manifest.dart';
import '../../plugins/services/plugin_repository.dart';
import '../../plugins/services/plugin_validator.dart';
import '../models/source_models.dart';
import '../services/source_import_service.dart';
import '../services/source_registry.dart';
import '../services/story_source.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final _registry = SourceRegistry();
  final _importService = SourceImportService();
  final _pluginRepository = PluginRepository();
  final _queryController = TextEditingController();
  List<SourceSearchResult> _results = const [];
  List<PluginManifest> _plugins = const [];
  bool _isSearching = false;
  bool _isPluginBusy = false;

  Iterable<StorySource> get _searchableSources =>
      _registry.sources.where((source) => source.type == SourceType.mock);

  @override
  void initState() {
    super.initState();
    _loadPlugins();
    _searchDemo('');
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nguồn truyện')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Danh sách nguồn',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ..._registry.sources.map(_SourceTile.new),
                const SizedBox(height: 28),
                _PluginSection(
                  plugins: _plugins,
                  isBusy: _isPluginBusy,
                  onAdd: _installPlugin,
                  onAddSample: _installSamplePlugins,
                  onToggle: _togglePlugin,
                  onDelete: _deletePlugin,
                ),
                const SizedBox(height: 28),
                Text(
                  'Tìm từ nguồn',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nguồn này chỉ dùng dữ liệu mẫu offline, không gọi internet.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Tìm từ nguồn',
                  ),
                  onSubmitted: _searchDemo,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isSearching
                      ? null
                      : () => _searchDemo(_queryController.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm từ nguồn'),
                ),
                const SizedBox(height: 16),
                if (_isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (_results.isEmpty)
                  const Text('Không tìm thấy truyện')
                else
                  ..._results.map((result) {
                    return _SourceResultTile(
                      result: result,
                      onTap: () => _openSourceDetail(result),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _searchDemo(String query) async {
    setState(() => _isSearching = true);
    final results = <SourceSearchResult>[];
    for (final source in _searchableSources) {
      results.addAll(await source.searchStories(query));
    }
    for (final source in await _pluginRepository.loadInstalledSources()) {
      results.addAll(await source.searchStories(query));
    }
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Future<void> _openSourceDetail(SourceSearchResult result) async {
    final source =
        _registry.byId(result.sourceId) ??
        _firstSourceById(
          await _pluginRepository.loadInstalledSources(),
          result.sourceId,
        );
    if (source == null) return;
    final detail = await source.getStoryDetail(result.story.id);
    if (detail == null) return;
    final chapters = await source.getChapterList(detail.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SourceStoryDetailScreen(
          source: source,
          story: detail,
          chapters: chapters,
          importService: _importService,
        ),
      ),
    );
  }

  Future<void> _loadPlugins() async {
    final plugins = await _pluginRepository.loadInstalled();
    if (!mounted) return;
    setState(() => _plugins = plugins);
  }

  Future<void> _installPlugin() async {
    await _runPluginAction(() async {
      final manifest = await _pluginRepository.pickAndInstallPlugin();
      if (manifest == null) return;
      _showMessage('Đã thêm plugin: ${manifest.name}');
    });
  }

  Future<void> _installSamplePlugins() async {
    await _runPluginAction(() async {
      await _pluginRepository.installFromAsset(
        'assets/sample_plugins/public_domain_text_plugin.json',
      );
      await _pluginRepository.installFromAsset(
        'assets/sample_plugins/public_domain_comic_plugin.json',
      );
      _showMessage('Đã thêm plugin mẫu');
    });
  }

  Future<void> _togglePlugin(PluginManifest plugin, bool enabled) async {
    await _runPluginAction(
      () => _pluginRepository.setEnabled(plugin.id, enabled),
    );
  }

  Future<void> _deletePlugin(PluginManifest plugin) async {
    await _runPluginAction(() => _pluginRepository.delete(plugin.id));
  }

  Future<void> _runPluginAction(Future<void> Function() action) async {
    setState(() => _isPluginBusy = true);
    try {
      await action();
      await _loadPlugins();
      await _searchDemo(_queryController.text);
    } on PluginValidationException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Plugin không hợp lệ');
    } finally {
      if (mounted) setState(() => _isPluginBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  StorySource? _firstSourceById(List<StorySource> sources, String sourceId) {
    for (final source in sources) {
      if (source.id == sourceId) return source;
    }
    return null;
  }
}

class _PluginSection extends StatelessWidget {
  const _PluginSection({
    required this.plugins,
    required this.isBusy,
    required this.onAdd,
    required this.onAddSample,
    required this.onToggle,
    required this.onDelete,
  });

  final List<PluginManifest> plugins;
  final bool isBusy;
  final VoidCallback onAdd;
  final VoidCallback onAddSample;
  final void Function(PluginManifest plugin, bool enabled) onToggle;
  final ValueChanged<PluginManifest> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plugin nguồn truyện',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Plugin này không chạy mã thực thi, chỉ dùng cấu hình an toàn.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isBusy ? null : onAdd,
              icon: const Icon(Icons.extension_outlined),
              label: const Text('Thêm plugin'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onAddSample,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Thêm plugin mẫu'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (plugins.isEmpty)
          const Text('Chưa có plugin đã cài')
        else
          ...plugins.map((plugin) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: const Icon(Icons.extension_outlined),
                title: Text(plugin.name),
                subtitle: Text(
                  '${plugin.description}\nGiấy phép: ${plugin.license}\nNguồn dữ liệu: ${plugin.sourceType}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: plugin.isEnabled ? 'Tắt plugin' : 'Bật plugin',
                      onPressed: isBusy
                          ? null
                          : () => onToggle(plugin, !plugin.isEnabled),
                      icon: Icon(
                        plugin.isEnabled
                            ? Icons.toggle_on_outlined
                            : Icons.toggle_off_outlined,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Xóa plugin',
                      onPressed: isBusy ? null : () => onDelete(plugin),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile(this.source);

  final StorySource source;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          source.type == SourceType.local
              ? Icons.folder_outlined
              : source.id == 'mock_comic'
              ? Icons.collections_outlined
              : Icons.public_outlined,
        ),
        title: Text(source.name),
        subtitle: Text('${source.description}\n${source.info.typeLabel}'),
        isThreeLine: true,
        trailing: Switch(value: source.isEnabled, onChanged: null),
      ),
    );
  }
}

class _SourceResultTile extends StatelessWidget {
  const _SourceResultTile({required this.result, required this.onTap});

  final SourceSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isComic = result.story.contentType == 'comic';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          isComic ? Icons.collections_outlined : Icons.menu_book_outlined,
        ),
        title: Text(result.story.title),
        subtitle: Text(
          '${result.story.author}\n${isComic ? 'Truyện tranh' : 'Truyện chữ'} - ${result.story.description}',
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}

class SourceStoryDetailScreen extends StatelessWidget {
  const SourceStoryDetailScreen({
    super.key,
    required this.source,
    required this.story,
    required this.chapters,
    required this.importService,
  });

  final StorySource source;
  final SourceStory story;
  final List<SourceChapter> chapters;
  final SourceImportService importService;

  bool get _isComic => story.contentType == 'comic';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(story.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  story.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tác giả: ${story.author}'),
                const SizedBox(height: 8),
                Text(_isComic ? 'Truyện tranh' : 'Truyện chữ'),
                const SizedBox(height: 8),
                Text(story.description),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _addToLibrary(context),
                  icon: Icon(
                    _isComic
                        ? Icons.collections_outlined
                        : Icons.library_add_outlined,
                  ),
                  label: Text(
                    _isComic ? 'Xem truyện tranh' : 'Thêm vào thư viện',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Danh sách chương',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...chapters.map((chapter) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(
                        chapter.contentKind == SourceContentKind.images
                            ? Icons.image_outlined
                            : Icons.article_outlined,
                      ),
                      title: Text(chapter.title),
                      subtitle: Text(
                        chapter.contentKind == SourceContentKind.images
                            ? '${chapter.imagePaths.length} trang ảnh'
                            : 'Truyện chữ',
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addToLibrary(BuildContext context) async {
    final draft = await importService.buildImportDraft(
      source: source,
      sourceStory: story,
    );
    if (draft == null || !context.mounted) return;
    final controller = AppScope.of(context);
    final savedStory = draft.isComic
        ? await controller.addComicStory(draft.story, draft.comicChapters)
        : await controller.addStory(draft.story, draft.chapters);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          draft.isComic
              ? 'Đã thêm truyện tranh vào thư viện'
              : 'Đã thêm vào thư viện',
        ),
      ),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => StoryDetailScreen(storyId: savedStory.id),
      ),
    );
  }
}
