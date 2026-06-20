import 'package:flutter/material.dart';

import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import '../models/plugin_search_result.dart';
import '../services/plugin_catalog_service.dart';
import '../services/plugin_repository.dart';
import '../services/plugin_search_service.dart';
import 'plugin_story_detail_screen.dart';

class PluginSearchScreen extends StatefulWidget {
  const PluginSearchScreen({
    super.key,
    this.pluginRepository,
    this.catalogService,
    this.searchService = const PluginSearchService(),
  });

  final PluginRepository? pluginRepository;
  final PluginCatalogService? catalogService;
  final PluginSearchService searchService;

  @override
  State<PluginSearchScreen> createState() => _PluginSearchScreenState();
}

class _PluginSearchScreenState extends State<PluginSearchScreen> {
  final _queryController = TextEditingController();

  late final PluginRepository _pluginRepository;
  late final PluginCatalogService _catalogService;

  List<PluginManifest> _enabledPlugins = const [];
  Map<String, List<PluginCatalogStory>> _cache = const {};
  List<PluginSearchResult> _results = const [];

  String? _selectedPluginId;
  PluginSearchContentFilter _contentFilter = PluginSearchContentFilter.all;
  PluginSearchSortMode _sortMode = PluginSearchSortMode.updatedDesc;

  bool _isLoading = true;
  bool _isSyncing = false;
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    _pluginRepository = widget.pluginRepository ?? PluginRepository();
    _catalogService = widget.catalogService ?? PluginCatalogService();
    _queryController.addListener(_applySearch);
    _load();
  }

  @override
  void dispose() {
    _queryController
      ..removeListener(_applySearch)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final plugins = (await _pluginRepository.getInstalledPlugins())
        .where((plugin) => plugin.isEnabled)
        .toList();

    final cache = <String, List<PluginCatalogStory>>{};
    for (final plugin in plugins) {
      cache[plugin.id] = await _catalogService.getCachedStories(plugin.id);
    }

    if (!mounted) return;

    final selectedStillExists =
        _selectedPluginId == null ||
        plugins.any((plugin) => plugin.id == _selectedPluginId);

    setState(() {
      _enabledPlugins = plugins;
      _cache = cache;
      _isLoading = false;
      if (!selectedStillExists) {
        _selectedPluginId = null;
      }
    });

    _applySearch();
  }

  void _applySearch() {
    if (!mounted) return;

    setState(() {
      _results = widget.searchService.search(
        plugins: _enabledPlugins,
        cachedStories: _cache,
        query: _queryController.text,
        pluginId: _selectedPluginId,
        contentFilter: _contentFilter,
        sortMode: _sortMode,
      );
    });
  }

  Future<void> _syncAll() async {
    final plugins = _enabledPlugins
        .where(
          (plugin) =>
              plugin.sourceType == 'api_json' &&
              plugin.features.catalog &&
              (plugin.endpoints['catalog']?.trim().isNotEmpty ?? false),
        )
        .toList();

    if (plugins.isEmpty) {
      _showMessage('Chưa có plugin nào có danh mục để đồng bộ');
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncStatus = 'Đang đồng bộ danh mục...';
    });

    var success = 0;
    var failed = 0;

    for (var i = 0; i < plugins.length; i++) {
      final plugin = plugins[i];
      if (!mounted) return;

      setState(
        () => _syncStatus = 'Đang đồng bộ ${i + 1}/${plugins.length} plugin...',
      );

      try {
        await _catalogService.syncCatalog(plugin.id);
        success++;
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _syncStatus = null;
    });

    await _load();

    _showMessage(
      failed == 0
          ? 'Đã đồng bộ $success plugin'
          : 'Đã đồng bộ $success plugin. Một số plugin đồng bộ thất bại: $failed',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasEnabledPlugins = _enabledPlugins.isNotEmpty;
    final hasAnyCache = _cache.values.any((stories) => stories.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm truyện từ plugin'),
        actions: [
          IconButton(
            tooltip: 'Đồng bộ tất cả',
            onPressed: _isSyncing ? null : _syncAll,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Header(onSyncAll: _isSyncing ? null : _syncAll),
                      if (_syncStatus != null) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 8),
                        Text(_syncStatus!),
                      ],
                      const SizedBox(height: 18),
                      if (!hasEnabledPlugins)
                        _EmptyState(
                          icon: Icons.extension_off_outlined,
                          title: 'Chưa có plugin nào đang bật',
                          message:
                              'Hãy cài và bật plugin trước khi tìm truyện.',
                          actionLabel: 'Quản lý plugin',
                          onAction: () => Navigator.of(context).maybePop(),
                        )
                      else ...[
                        _SearchControls(
                          queryController: _queryController,
                          plugins: _enabledPlugins,
                          selectedPluginId: _selectedPluginId,
                          contentFilter: _contentFilter,
                          sortMode: _sortMode,
                          onPluginChanged: (value) {
                            setState(() => _selectedPluginId = value);
                            _applySearch();
                          },
                          onContentFilterChanged: (value) {
                            setState(() => _contentFilter = value);
                            _applySearch();
                          },
                          onSortChanged: (value) {
                            setState(() => _sortMode = value);
                            _applySearch();
                          },
                        ),
                        const SizedBox(height: 16),
                        if (!hasAnyCache)
                          _EmptyState(
                            icon: Icons.cloud_sync_outlined,
                            title: 'Plugin chưa có danh mục đã đồng bộ',
                            message:
                                'Đồng bộ danh mục để tìm trong metadata truyện. App không tải nội dung chương khi tìm kiếm.',
                            actionLabel: 'Đồng bộ tất cả',
                            onAction: _isSyncing ? null : _syncAll,
                          )
                        else if (_results.isEmpty)
                          const _EmptyState(
                            icon: Icons.search_off_outlined,
                            title: 'Không tìm thấy truyện phù hợp',
                            message: 'Thử từ khóa khác hoặc đổi bộ lọc.',
                          )
                        else
                          _ResultGrid(results: _results),
                      ],
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

class _Header extends StatelessWidget {
  const _Header({required this.onSyncAll});

  final VoidCallback? onSyncAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;

            final title = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.travel_explore, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tìm truyện từ plugin',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tìm trong danh mục đã đồng bộ từ các plugin đang bật',
                      ),
                    ],
                  ),
                ),
              ],
            );

            final action = FilledButton.icon(
              onPressed: onSyncAll,
              icon: const Icon(Icons.sync),
              label: const Text('Đồng bộ tất cả'),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft, child: action),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 16),
                action,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.queryController,
    required this.plugins,
    required this.selectedPluginId,
    required this.contentFilter,
    required this.sortMode,
    required this.onPluginChanged,
    required this.onContentFilterChanged,
    required this.onSortChanged,
  });

  final TextEditingController queryController;
  final List<PluginManifest> plugins;
  final String? selectedPluginId;
  final PluginSearchContentFilter contentFilter;
  final PluginSearchSortMode sortMode;
  final ValueChanged<String?> onPluginChanged;
  final ValueChanged<PluginSearchContentFilter> onContentFilterChanged;
  final ValueChanged<PluginSearchSortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveSelectedPluginId =
        selectedPluginId != null &&
            plugins.any((plugin) => plugin.id == selectedPluginId)
        ? selectedPluginId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: queryController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Nhập tên truyện, tác giả hoặc thể loại',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final isNarrow = maxWidth < 760;

            final pluginWidth = isNarrow
                ? maxWidth
                : (maxWidth * 0.34).clamp(280.0, 380.0).toDouble();

            final sortWidth = isNarrow ? maxWidth : 260.0;

            final contentFilterWidth = isNarrow
                ? maxWidth
                : (maxWidth - pluginWidth - sortWidth - 24)
                      .clamp(260.0, 460.0)
                      .toDouble();

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: pluginWidth,
                  child: _PluginDropdown(
                    plugins: plugins,
                    selectedPluginId: effectiveSelectedPluginId,
                    onChanged: onPluginChanged,
                  ),
                ),
                SizedBox(
                  width: contentFilterWidth,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _ContentTypeFilter(
                      value: contentFilter,
                      onChanged: onContentFilterChanged,
                    ),
                  ),
                ),
                SizedBox(
                  width: sortWidth,
                  child: _SortDropdown(
                    value: sortMode,
                    onChanged: onSortChanged,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PluginDropdown extends StatelessWidget {
  const _PluginDropdown({
    required this.plugins,
    required this.selectedPluginId,
    required this.onChanged,
  });

  final List<PluginManifest> plugins;
  final String? selectedPluginId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: ValueKey('plugin-filter-$selectedPluginId-${plugins.length}'),
      isExpanded: true,
      initialValue: selectedPluginId,
      decoration: const InputDecoration(
        labelText: 'Plugin',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text(
            'Tất cả plugin',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        for (final plugin in plugins)
          DropdownMenuItem<String?>(
            value: plugin.id,
            child: Text(
              plugin.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ContentTypeFilter extends StatelessWidget {
  const _ContentTypeFilter({required this.value, required this.onChanged});

  final PluginSearchContentFilter value;
  final ValueChanged<PluginSearchContentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PluginSearchContentFilter>(
      segments: const [
        ButtonSegment(
          value: PluginSearchContentFilter.all,
          label: Text('Tất cả'),
        ),
        ButtonSegment(
          value: PluginSearchContentFilter.text,
          label: Text('Truyện chữ'),
        ),
        ButtonSegment(
          value: PluginSearchContentFilter.comic,
          label: Text('Truyện tranh'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (values) => onChanged(values.single),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.value, required this.onChanged});

  final PluginSearchSortMode value;
  final ValueChanged<PluginSearchSortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<PluginSearchSortMode>(
      key: ValueKey('sort-filter-$value'),
      isExpanded: true,
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Sắp xếp',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(
          value: PluginSearchSortMode.updatedDesc,
          child: Text(
            'Mới cập nhật',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: PluginSearchSortMode.titleAz,
          child: Text(
            'Tên A-Z',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: PluginSearchSortMode.authorAz,
          child: Text(
            'Tác giả',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        DropdownMenuItem(
          value: PluginSearchSortMode.pluginName,
          child: Text(
            'Nguồn plugin',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.results});

  final List<PluginSearchResult> results;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 4
            : width >= 820
            ? 3
            : width >= 560
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 3.2 : 1.05,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) => _ResultCard(result: results[index]),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final PluginSearchResult result;

  @override
  Widget build(BuildContext context) {
    final story = result.story;
    final isComic = story.contentType == 'comic';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PluginStoryDetailScreen(plugin: result.plugin, story: story),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Cover(url: story.coverUrl, isComic: isComic),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      story.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.plugin.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(isComic ? 'Truyện tranh' : 'Truyện chữ'),
                        if (story.status != null) _Badge(story.status!),
                        for (final genre in story.genres.take(2)) _Badge(genre),
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
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.isComic});

  final String? url;
  final bool isComic;

  @override
  Widget build(BuildContext context) {
    final child = url == null || url!.isEmpty
        ? Icon(isComic ? Icons.collections_outlined : Icons.menu_book_outlined)
        : Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image_outlined),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(width: 74, height: 104, child: Center(child: child)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

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
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 54),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            children: [
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

