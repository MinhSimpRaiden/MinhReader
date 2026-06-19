import 'package:flutter/material.dart';

import '../../library/providers/app_controller.dart';
import '../../library/screens/story_detail_screen.dart';
import '../../plugins/models/plugin_manifest.dart';
import '../../plugins/screens/add_plugin_screen.dart';
import '../../plugins/screens/plugin_catalog_screen.dart';
import '../../plugins/services/plugin_catalog_service.dart';
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
  final _catalogService = PluginCatalogService();
  final _queryController = TextEditingController();
  List<SourceSearchResult> _results = const [];
  List<PluginManifest> _plugins = const [];
  final Map<String, PluginCatalogStats> _catalogStats = {};
  bool _isSearching = false;
  bool _isPluginBusy = false;
  String _selectedPluginId = '__all__';

  Iterable<StorySource> get _localSources =>
      _registry.sources.where((source) => source.type == SourceType.local);

  Iterable<StorySource> get _demoSources =>
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
                _SectionTitle('Nguồn local'),
                ..._localSources.map(_SourceTile.new),
                const SizedBox(height: 24),
                _SectionTitle('Nguồn demo'),
                ..._demoSources.map(_SourceTile.new),
                const SizedBox(height: 28),
                _PluginCatalogSection(
                  plugins: _plugins,
                  isBusy: _isPluginBusy,
                  onAdd: _openAddPlugin,
                  onAddSample: _installSamplePlugins,
                  onToggle: _togglePlugin,
                  onDelete: _deletePlugin,
                  onInfo: _showPluginInfo,
                  catalogStats: _catalogStats,
                  onSyncCatalog: _syncPluginCatalog,
                  onRefreshCatalog: _refreshPluginCatalog,
                  onOpenCatalog: _openPluginCatalog,
                  onClearCatalog: _clearPluginCatalog,
                ),
                const SizedBox(height: 28),
                _SearchPanel(
                  queryController: _queryController,
                  isSearching: _isSearching,
                  plugins: _plugins,
                  selectedPluginId: _selectedPluginId,
                  onPluginChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPluginId = value);
                    }
                  },
                  onSearchAll: () => _searchDemo(_queryController.text),
                  onSearchPlugin: () => _searchPlugins(_queryController.text),
                  onSubmitted: _searchDemo,
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
    for (final source in _demoSources) {
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

  Future<void> _searchPlugins(String query) async {
    setState(() => _isSearching = true);
    final results = <SourceSearchResult>[];
    final sources = await _pluginRepository.loadInstalledSources();
    for (final source in sources) {
      if (_selectedPluginId != '__all__' && source.id != _selectedPluginId) {
        continue;
      }
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
    final plugins = await _pluginRepository.getInstalledPlugins();
    if (!mounted) return;
    setState(() => _plugins = plugins);
    await _loadCatalogStats(plugins);
  }

  Future<void> _loadCatalogStats(List<PluginManifest> plugins) async {
    final stats = <String, PluginCatalogStats>{};
    for (final plugin in plugins.where(
      (item) => item.sourceType == 'api_json',
    )) {
      final entry = await _catalogService.getCacheEntry(plugin.id);
      stats[plugin.id] = PluginCatalogStats(
        storyCount: entry.stories.length,
        lastSyncAt: entry.lastSyncAt,
        pageSynced: entry.pageSynced,
        hasNextPage: entry.hasNextPage,
      );
    }
    if (!mounted) return;
    setState(() {
      _catalogStats
        ..clear()
        ..addAll(stats);
    });
  }

  Future<void> _openAddPlugin() async {
    final installed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPluginScreen(repository: _pluginRepository),
      ),
    );
    if (installed == true) {
      await _loadPlugins();
      await _searchDemo(_queryController.text);
    }
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
      () => enabled
          ? _pluginRepository.enablePlugin(plugin.id)
          : _pluginRepository.disablePlugin(plugin.id),
    );
  }

  Future<void> _deletePlugin(PluginManifest plugin) async {
    await _runPluginAction(() => _pluginRepository.deletePlugin(plugin.id));
  }

  Future<void> _syncPluginCatalog(PluginManifest plugin) async {
    await _runPluginAction(() async {
      final result = await _catalogService.syncCatalog(plugin.id);
      _showMessage('Đã đồng bộ ${result.syncedCount} truyện');
    });
  }

  Future<void> _refreshPluginCatalog(PluginManifest plugin) async {
    await _runPluginAction(() async {
      final result = await _catalogService.refreshCatalog(plugin.id);
      _showMessage('Đã đồng bộ ${result.syncedCount} truyện');
    });
  }

  Future<void> _clearPluginCatalog(PluginManifest plugin) async {
    await _runPluginAction(() async {
      await _catalogService.clearCache(plugin.id);
      _showMessage('Đã xóa cache danh mục');
    });
  }

  Future<void> _openPluginCatalog(PluginManifest plugin) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PluginCatalogScreen(plugin: plugin)),
    );
    await _loadPlugins();
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

  Future<void> _showPluginInfo(PluginManifest plugin) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(plugin.name),
        content: SingleChildScrollView(
          child: Text(
            [
              'Version: ${plugin.version}',
              'Tác giả: ${plugin.author}',
              'Loại nội dung: ${_pluginContentLabel(plugin)}',
              'Trạng thái: ${plugin.isEnabled ? 'Plugin đang bật' : 'Plugin đang tắt'}',
              'Giấy phép: ${plugin.license.trim().isEmpty ? 'Chưa khai báo' : plugin.license}',
              'Nguồn dữ liệu: ${plugin.sourceType}',
              '',
              plugin.description,
              '',
              'Plugin này không chạy mã thực thi, chỉ dùng cấu hình JSON an toàn',
            ].join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  StorySource? _firstSourceById(List<StorySource> sources, String sourceId) {
    for (final source in sources) {
      if (source.id == sourceId) return source;
    }
    return null;
  }

  String _pluginContentLabel(PluginManifest plugin) {
    return switch (plugin.contentType) {
      'comic' => 'Truyện tranh',
      'mixed' => 'Hỗn hợp',
      _ => 'Truyện chữ',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.queryController,
    required this.isSearching,
    required this.plugins,
    required this.selectedPluginId,
    required this.onPluginChanged,
    required this.onSearchAll,
    required this.onSearchPlugin,
    required this.onSubmitted,
  });

  final TextEditingController queryController;
  final bool isSearching;
  final List<PluginManifest> plugins;
  final String selectedPluginId;
  final ValueChanged<String?> onPluginChanged;
  final VoidCallback onSearchAll;
  final VoidCallback onSearchPlugin;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final enabledPlugins = plugins.where((plugin) => plugin.isEnabled).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Tìm từ nguồn'),
        const Text('Nguồn demo và plugin chỉ dùng dữ liệu hợp pháp/offline.'),
        const SizedBox(height: 12),
        TextField(
          controller: queryController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Tìm từ nguồn',
          ),
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isSearching ? null : onSearchAll,
          icon: const Icon(Icons.search),
          label: const Text('Tìm từ nguồn'),
        ),
        const SizedBox(height: 24),
        _SectionTitle('Tìm trong plugin'),
        DropdownButtonFormField<String>(
          initialValue: selectedPluginId,
          decoration: const InputDecoration(labelText: 'Plugin'),
          items: [
            const DropdownMenuItem(
              value: '__all__',
              child: Text('Tất cả plugin đang bật'),
            ),
            for (final plugin in enabledPlugins)
              DropdownMenuItem(value: plugin.id, child: Text(plugin.name)),
          ],
          onChanged: onPluginChanged,
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isSearching ? null : onSearchPlugin,
          icon: const Icon(Icons.extension_outlined),
          label: const Text('Tìm trong plugin'),
        ),
        if (plugins.isNotEmpty && enabledPlugins.isEmpty) ...[
          const SizedBox(height: 8),
          const Text('Nguồn này chưa được bật'),
        ],
        if (plugins.isEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Plugin đã được cài. Tính năng đọc dữ liệu từ plugin sẽ được hoàn thiện ở bước tiếp theo.',
          ),
        ],
      ],
    );
  }
}

class _PluginCatalogSection extends StatelessWidget {
  const _PluginCatalogSection({
    required this.plugins,
    required this.isBusy,
    required this.onAdd,
    required this.onAddSample,
    required this.onToggle,
    required this.onDelete,
    required this.onInfo,
    required this.catalogStats,
    required this.onSyncCatalog,
    required this.onRefreshCatalog,
    required this.onOpenCatalog,
    required this.onClearCatalog,
  });

  final List<PluginManifest> plugins;
  final bool isBusy;
  final VoidCallback onAdd;
  final VoidCallback onAddSample;
  final void Function(PluginManifest plugin, bool enabled) onToggle;
  final ValueChanged<PluginManifest> onDelete;
  final ValueChanged<PluginManifest> onInfo;
  final Map<String, PluginCatalogStats> catalogStats;
  final ValueChanged<PluginManifest> onSyncCatalog;
  final ValueChanged<PluginManifest> onRefreshCatalog;
  final ValueChanged<PluginManifest> onOpenCatalog;
  final ValueChanged<PluginManifest> onClearCatalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Plugin'),
        Text(
          'Plugin nguồn truyện',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text('Plugin là cấu hình JSON an toàn, không chạy mã thực thi.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isBusy ? null : onAdd,
              icon: const Icon(Icons.add),
              label: const Text('+ Thêm plugin'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onAddSample,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Thêm plugin mẫu'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Plugin đã cài',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (plugins.isEmpty)
          const Text('Chưa có plugin đã cài')
        else
          ...plugins.map(
            (plugin) => _PluginCatalogTile(
              plugin: plugin,
              isBusy: isBusy,
              stats: catalogStats[plugin.id],
              onToggle: onToggle,
              onDelete: onDelete,
              onInfo: onInfo,
              onSyncCatalog: onSyncCatalog,
              onRefreshCatalog: onRefreshCatalog,
              onOpenCatalog: onOpenCatalog,
              onClearCatalog: onClearCatalog,
            ),
          ),
      ],
    );
  }
}

class _PluginCatalogTile extends StatelessWidget {
  const _PluginCatalogTile({
    required this.plugin,
    required this.isBusy,
    required this.stats,
    required this.onToggle,
    required this.onDelete,
    required this.onInfo,
    required this.onSyncCatalog,
    required this.onRefreshCatalog,
    required this.onOpenCatalog,
    required this.onClearCatalog,
  });

  final PluginManifest plugin;
  final bool isBusy;
  final PluginCatalogStats? stats;
  final void Function(PluginManifest plugin, bool enabled) onToggle;
  final ValueChanged<PluginManifest> onDelete;
  final ValueChanged<PluginManifest> onInfo;
  final ValueChanged<PluginManifest> onSyncCatalog;
  final ValueChanged<PluginManifest> onRefreshCatalog;
  final ValueChanged<PluginManifest> onOpenCatalog;
  final ValueChanged<PluginManifest> onClearCatalog;

  @override
  Widget build(BuildContext context) {
    final contentLabel = switch (plugin.contentType) {
      'comic' => 'Truyện tranh',
      'mixed' => 'Hỗn hợp',
      _ => 'Truyện chữ',
    };
    final isApiPlugin = plugin.sourceType == 'api_json';
    final catalogLine = isApiPlugin
        ? '\nCache: ${stats?.storyCount ?? 0} truyện'
              ' - Trang: ${stats?.pageSynced ?? 0}'
              '${stats?.lastSyncAt == null ? '' : '\nLần đồng bộ gần nhất: ${stats!.lastSyncAt!.toLocal()}'}'
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: const Icon(Icons.extension_outlined),
        title: Text(plugin.name),
        subtitle: Text(
          '${plugin.description}\nVersion: ${plugin.version} - Tác giả: ${plugin.author}\n$contentLabel - ${plugin.isEnabled ? 'Plugin đang bật' : 'Plugin đang tắt'}\nGiấy phép: ${plugin.license.trim().isEmpty ? 'Chưa khai báo' : plugin.license}\nNguồn dữ liệu: ${plugin.sourceType}$catalogLine',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !isBusy,
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                onToggle(plugin, !plugin.isEnabled);
              case 'info':
                onInfo(plugin);
              case 'syncCatalog':
                onSyncCatalog(plugin);
              case 'refreshCatalog':
                onRefreshCatalog(plugin);
              case 'openCatalog':
                onOpenCatalog(plugin);
              case 'clearCatalog':
                onClearCatalog(plugin);
              case 'delete':
                onDelete(plugin);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(plugin.isEnabled ? 'Tắt plugin' : 'Bật plugin'),
            ),
            const PopupMenuItem(value: 'info', child: Text('Xem thông tin')),
            if (isApiPlugin && plugin.isEnabled) ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'syncCatalog',
                child: Text('Đồng bộ danh mục'),
              ),
              const PopupMenuItem(
                value: 'refreshCatalog',
                child: Text('Làm mới danh mục'),
              ),
              const PopupMenuItem(
                value: 'openCatalog',
                child: Text('Truyện đã cache'),
              ),
              const PopupMenuItem(
                value: 'clearCatalog',
                child: Text('Xóa cache'),
              ),
            ],
            const PopupMenuItem(value: 'delete', child: Text('Xóa plugin')),
          ],
        ),
      ),
    );
  }
}

class PluginCatalogStats {
  const PluginCatalogStats({
    required this.storyCount,
    required this.lastSyncAt,
    required this.pageSynced,
    required this.hasNextPage,
  });

  final int storyCount;
  final DateTime? lastSyncAt;
  final int pageSynced;
  final bool hasNextPage;
}

// ignore: unused_element
class _PluginSection extends StatelessWidget {
  const _PluginSection({
    required this.plugins,
    required this.isBusy,
    required this.onAdd,
    required this.onAddSample,
    required this.onToggle,
    required this.onDelete,
    required this.onInfo,
  });

  final List<PluginManifest> plugins;
  final bool isBusy;
  final VoidCallback onAdd;
  final VoidCallback onAddSample;
  final void Function(PluginManifest plugin, bool enabled) onToggle;
  final ValueChanged<PluginManifest> onDelete;
  final ValueChanged<PluginManifest> onInfo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Plugin'),
        Text(
          'Plugin nguồn truyện',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Plugin này không chạy mã thực thi, chỉ dùng cấu hình JSON an toàn',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isBusy ? null : onAdd,
              icon: const Icon(Icons.add),
              label: const Text('+ Thêm plugin'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onAddSample,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Thêm plugin mẫu'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Plugin đã cài',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (plugins.isEmpty)
          const Text('Chưa có plugin đã cài')
        else
          ...plugins.map(
            (plugin) => _PluginTile(
              plugin: plugin,
              isBusy: isBusy,
              onToggle: onToggle,
              onDelete: onDelete,
              onInfo: onInfo,
            ),
          ),
      ],
    );
  }
}

class _PluginTile extends StatelessWidget {
  const _PluginTile({
    required this.plugin,
    required this.isBusy,
    required this.onToggle,
    required this.onDelete,
    required this.onInfo,
  });

  final PluginManifest plugin;
  final bool isBusy;
  final void Function(PluginManifest plugin, bool enabled) onToggle;
  final ValueChanged<PluginManifest> onDelete;
  final ValueChanged<PluginManifest> onInfo;

  @override
  Widget build(BuildContext context) {
    final contentLabel = switch (plugin.contentType) {
      'comic' => 'Truyện tranh',
      'mixed' => 'Hỗn hợp',
      _ => 'Truyện chữ',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: const Icon(Icons.extension_outlined),
        title: Text(plugin.name),
        subtitle: Text(
          '${plugin.description}\nVersion: ${plugin.version} - Tác giả: ${plugin.author}\n$contentLabel - ${plugin.isEnabled ? 'Plugin đang bật' : 'Plugin đang tắt'}\nGiấy phép: ${plugin.license.trim().isEmpty ? 'Chưa khai báo' : plugin.license}\nNguồn dữ liệu: ${plugin.sourceType}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !isBusy,
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                onToggle(plugin, !plugin.isEnabled);
              case 'info':
                onInfo(plugin);
              case 'delete':
                onDelete(plugin);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(plugin.isEnabled ? 'Tắt plugin' : 'Bật plugin'),
            ),
            const PopupMenuItem(value: 'info', child: Text('Xem thông tin')),
            const PopupMenuItem(value: 'delete', child: Text('Xóa plugin')),
          ],
        ),
      ),
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
                _SectionTitle('Danh sách chương'),
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
