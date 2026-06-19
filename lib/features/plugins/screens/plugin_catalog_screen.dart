import 'package:flutter/material.dart';

import '../models/plugin_catalog.dart';
import '../models/plugin_manifest.dart';
import '../services/plugin_catalog_service.dart';
import 'plugin_story_detail_screen.dart';

class PluginCatalogScreen extends StatefulWidget {
  const PluginCatalogScreen({
    super.key,
    required this.plugin,
    this.catalogService,
  });

  final PluginManifest plugin;
  final PluginCatalogService? catalogService;

  @override
  State<PluginCatalogScreen> createState() => _PluginCatalogScreenState();
}

class _PluginCatalogScreenState extends State<PluginCatalogScreen> {
  final _queryController = TextEditingController();
  List<PluginCatalogStory> _stories = const [];
  bool _isLoading = true;

  late final PluginCatalogService _catalogService;

  @override
  void initState() {
    super.initState();
    _catalogService = widget.catalogService ?? PluginCatalogService();
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _load([String query = '']) async {
    setState(() => _isLoading = true);
    final stories = query.trim().isEmpty
        ? await _catalogService.getCachedStories(widget.plugin.id)
        : await _catalogService.searchCachedStories(widget.plugin.id, query);
    if (!mounted) return;
    setState(() {
      _stories = stories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Truyện đã cache - ${widget.plugin.name}')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _queryController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Tìm trong danh mục',
                  ),
                  onSubmitted: _load,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _load(_queryController.text),
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm trong danh mục'),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_stories.isEmpty)
                  const Text('Chưa có truyện trong cache')
                else
                  ..._stories.map(
                    (story) => _CachedStoryTile(
                      story: story,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PluginStoryDetailScreen(
                            plugin: widget.plugin,
                            story: story,
                          ),
                        ),
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
}

class _CachedStoryTile extends StatelessWidget {
  const _CachedStoryTile({required this.story, required this.onTap});

  final PluginCatalogStory story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isComic = story.contentType == 'comic';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: story.coverUrl == null || story.coverUrl!.isEmpty
            ? Icon(isComic ? Icons.collections_outlined : Icons.menu_book)
            : SizedBox(
                width: 48,
                height: 68,
                child: Image.network(
                  story.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              ),
        title: Text(story.title),
        subtitle: Text(
          '${story.author}\n${isComic ? 'Truyện tranh' : 'Truyện chữ'}'
          '${story.status == null ? '' : ' - ${story.status}'}'
          '${story.updatedAt == null ? '' : '\nCập nhật: ${story.updatedAt!.toLocal()}'}',
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
