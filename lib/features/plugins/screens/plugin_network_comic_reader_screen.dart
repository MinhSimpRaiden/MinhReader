import 'package:flutter/material.dart';

import '../models/plugin_runtime_models.dart';
import '../services/plugin_comic_image_safety.dart';
import '../services/plugin_http_client.dart';
import '../services/plugin_runtime_service.dart';

class PluginNetworkComicReaderScreen extends StatefulWidget {
  const PluginNetworkComicReaderScreen({
    super.key,
    required this.pluginId,
    required this.storyId,
    required this.storyTitle,
    required this.chapters,
    required this.initialChapterIndex,
    this.runtimeService,
  });

  final String pluginId;
  final String storyId;
  final String storyTitle;
  final List<PluginRuntimeChapter> chapters;
  final int initialChapterIndex;
  final PluginRuntimeService? runtimeService;

  @override
  State<PluginNetworkComicReaderScreen> createState() =>
      _PluginNetworkComicReaderScreenState();
}

class _PluginNetworkComicReaderScreenState
    extends State<PluginNetworkComicReaderScreen> {
  late final PluginRuntimeService _runtimeService;
  final _scrollController = ScrollController();
  var _chapterIndex = 0;
  var _images = const <String>[];
  var _isLoading = true;
  String? _errorMessage;
  var _visiblePage = 1;

  PluginRuntimeChapter get _chapter => widget.chapters.isEmpty
      ? const PluginRuntimeChapter(id: '', title: 'Chưa có chương', index: 0)
      : widget.chapters[_chapterIndex];

  bool get _canGoPrevious => _chapterIndex > 0;

  bool get _canGoNext => _chapterIndex < widget.chapters.length - 1;

  @override
  void initState() {
    super.initState();
    _runtimeService = widget.runtimeService ?? PluginRuntimeService();
    _chapterIndex = widget.chapters.isEmpty
        ? 0
        : widget.initialChapterIndex.clamp(0, widget.chapters.length - 1);
    _scrollController.addListener(_updateVisiblePage);
    _loadChapter();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateVisiblePage)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _images = const [];
      _visiblePage = 1;
    });
    if (widget.chapters.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Chưa có danh sách chương';
      });
      return;
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    try {
      final chapterImages = await _runtimeService.getComicChapterImages(
        widget.pluginId,
        _chapter.id,
      );
      if (!mounted) return;
      setState(() {
        _images = PluginComicImageSafety.normalizeImageUrls(
          chapterImages.images,
        );
        _isLoading = false;
      });
    } on PluginHttpException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải ảnh chương';
        _isLoading = false;
      });
    }
  }

  Future<void> _goToChapter(int index) async {
    if (index < 0 ||
        index >= widget.chapters.length ||
        index == _chapterIndex) {
      return;
    }
    setState(() => _chapterIndex = index);
    await _loadChapter();
  }

  void _updateVisiblePage() {
    if (!_scrollController.hasClients || _images.isEmpty) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      if (_visiblePage != 1) setState(() => _visiblePage = 1);
      return;
    }
    final ratio = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    final page = (ratio * (_images.length - 1)).round() + 1;
    if (page != _visiblePage) {
      setState(() => _visiblePage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.storyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: _buildBody(),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: const Color(0xFF18181B),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canGoPrevious
                      ? () => _goToChapter(_chapterIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Chương trước'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _images.isEmpty
                      ? 'Chương ${widget.chapters.isEmpty ? 0 : _chapterIndex + 1}/${widget.chapters.length}'
                      : 'Trang $_visiblePage/${_images.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canGoNext
                      ? () => _goToChapter(_chapterIndex + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Chương sau'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Đang tải ảnh chương...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return _ReaderMessage(
        icon: Icons.error_outline,
        title: 'Không thể tải ảnh chương',
        message: _errorMessage!,
        action: FilledButton.icon(
          onPressed: _loadChapter,
          icon: const Icon(Icons.refresh),
          label: const Text('Thử lại'),
        ),
      );
    }
    if (_images.isEmpty) {
      return const _ReaderMessage(
        icon: Icons.image_not_supported_outlined,
        title: 'Chương này chưa có ảnh',
        message: 'Plugin không trả về danh sách ảnh cho chương này.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        return _NetworkComicPage(
          url: _images[index],
          pageNumber: index + 1,
          pageCount: _images.length,
        );
      },
    );
  }
}

class _NetworkComicPage extends StatelessWidget {
  const _NetworkComicPage({
    required this.url,
    required this.pageNumber,
    required this.pageCount,
  });

  final String url;
  final int pageNumber;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    if (!PluginComicImageSafety.isSupportedImageUrl(url)) {
      return _ImageErrorPlaceholder(
        title: 'Không thể tải ảnh',
        message: 'URL ảnh không hợp lệ: ${_shortUrl(url)}',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Image.network(
        url,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const AspectRatio(
            aspectRatio: 2 / 3,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _ImageErrorPlaceholder(
            title: 'Không thể tải ảnh',
            message: 'Trang $pageNumber/$pageCount - ${_shortUrl(url)}',
          );
        },
      ),
    );
  }

  String _shortUrl(String value) {
    final clean = value.trim();
    if (clean.length <= 72) return clean;
    return '${clean.substring(0, 69)}...';
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(18),
      constraints: const BoxConstraints(minHeight: 180),
      color: const Color(0xFF242428),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.white70),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
