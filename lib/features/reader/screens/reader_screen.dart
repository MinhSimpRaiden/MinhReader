import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../library/providers/app_controller.dart';
import '../models/bookmark.dart';
import '../../settings/models/reading_settings.dart';
import '../../settings/services/reader_palette.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.storyId,
    required this.initialChapterIndex,
    this.initialScrollRatio,
  });

  final String storyId;
  final int initialChapterIndex;
  final double? initialScrollRatio;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late AppController _appController;
  late int _chapterIndex;
  Timer? _saveScrollTimer;
  double _chapterProgress = 0;
  bool _chromeVisible = true;
  bool _isRestoringScroll = false;
  String _searchQuery = '';
  List<int> _searchMatches = [];
  int _activeMatchIndex = 0;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.initialChapterIndex;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreReadingPlace());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appController = AppScope.of(context);
  }

  @override
  void dispose() {
    _saveScrollTimer?.cancel();
    unawaited(_saveProgress(scrollRatio: _currentScrollRatio()));
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final story = controller.storyById(widget.storyId);
    final chapters = controller.chaptersFor(widget.storyId);
    final settings = controller.settings;

    if (story == null || chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy nội dung đọc')),
      );
    }

    final chapter = chapters[_chapterIndex.clamp(0, chapters.length - 1)];
    final currentBookmark = controller.bookmarkNear(
      storyId: widget.storyId,
      chapterIndex: _chapterIndex,
      scrollRatio: _currentScrollRatio(),
    );
    final brightness = Theme.of(context).brightness;
    final background = ReaderPalette.background(
      settings.backgroundMode,
      brightness,
    );
    final foreground = ReaderPalette.foreground(
      settings.backgroundMode,
      brightness,
    );

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, chapters.length),
      child: Scaffold(
        backgroundColor: background,
        appBar: _chromeVisible
            ? AppBar(
                title: Text(chapter.title),
                backgroundColor: background,
                foregroundColor: foreground,
                actions: [
                  IconButton(
                    tooltip: 'Tìm trong chương',
                    onPressed: () => _showChapterSearch(chapter.content),
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: currentBookmark == null
                        ? 'Đánh dấu'
                        : 'Đã đánh dấu',
                    onPressed: () => _showBookmarkDialog(
                      chapterTitle: chapter.title,
                      existingBookmark: currentBookmark,
                    ),
                    icon: Icon(
                      currentBookmark == null
                          ? Icons.bookmark_add_outlined
                          : Icons.bookmark,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cài đặt đọc',
                    onPressed: () => _showReaderSettings(context),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              _ReaderProgressBar(
                progress: _chapterProgress,
                foreground: foreground,
                background: background,
                visible: _chromeVisible,
              ),
              if (_searchQuery.isNotEmpty && _chromeVisible)
                _SearchStatusBar(
                  query: _searchQuery,
                  matchCount: _searchMatches.length,
                  activeMatchIndex: _activeMatchIndex,
                  onPrevious: _searchMatches.isEmpty
                      ? null
                      : () => _goToSearchMatch(
                          _activeMatchIndex - 1,
                          chapter.content,
                        ),
                  onNext: _searchMatches.isEmpty
                      ? null
                      : () => _goToSearchMatch(
                          _activeMatchIndex + 1,
                          chapter.content,
                        ),
                  onClose: () => setState(() {
                    _searchQuery = '';
                    _searchMatches = [];
                    _activeMatchIndex = 0;
                  }),
                ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.sizeOf(context).width < 480 ? 18 : 28,
                          _chromeVisible ? 18 : 28,
                          MediaQuery.sizeOf(context).width < 480 ? 18 : 28,
                          36,
                        ),
                        children: [
                          Text(
                            story.title,
                            style: TextStyle(
                              color: foreground.withValues(alpha: 0.66),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            chapter.title,
                            style: TextStyle(
                              color: foreground,
                              fontSize: settings.fontSize + 6,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SelectableText.rich(
                            _highlightedChapterText(
                              chapter.content,
                              foreground,
                              settings,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _chromeVisible
                    ? _ReaderNavigationBar(
                        key: const ValueKey('reader-nav'),
                        background: background,
                        foreground: foreground,
                        chapterIndex: _chapterIndex,
                        chapterCount: chapters.length,
                        onBookmark: () => _showBookmarkDialog(
                          chapterTitle: chapter.title,
                          existingBookmark: currentBookmark,
                        ),
                        isBookmarked: currentBookmark != null,
                        onPrevious: _chapterIndex == 0
                            ? null
                            : () => _goToChapter(_chapterIndex - 1),
                        onNext: _chapterIndex >= chapters.length - 1
                            ? null
                            : () => _goToChapter(_chapterIndex + 1),
                      )
                    : const SizedBox.shrink(key: ValueKey('reader-nav-off')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _highlightedChapterText(
    String content,
    Color foreground,
    ReadingSettings settings,
  ) {
    final baseStyle = TextStyle(
      color: foreground,
      fontSize: settings.fontSize,
      height: settings.lineHeight,
      fontFamily: settings.fontFamily,
    );
    if (_searchQuery.isEmpty || _searchMatches.isEmpty) {
      return TextSpan(text: content, style: baseStyle);
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (var i = 0; i < _searchMatches.length; i++) {
      final start = _searchMatches[i];
      final end = start + _searchQuery.length;
      if (start > cursor) {
        spans.add(TextSpan(text: content.substring(cursor, start)));
      }
      spans.add(
        TextSpan(
          text: content.substring(start, end),
          style: TextStyle(
            backgroundColor: i == _activeMatchIndex
                ? Colors.amber.withValues(alpha: 0.75)
                : Colors.amber.withValues(alpha: 0.38),
            color: Colors.black,
            fontWeight: i == _activeMatchIndex ? FontWeight.w700 : null,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < content.length) {
      spans.add(TextSpan(text: content.substring(cursor)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  void _handleScroll() {
    if (_isRestoringScroll) return;
    final ratio = _currentScrollRatio();
    if ((ratio - _chapterProgress).abs() >= 0.005) {
      setState(() => _chapterProgress = ratio);
    }
    _saveScrollTimer?.cancel();
    _saveScrollTimer = Timer(const Duration(milliseconds: 900), () {
      _saveProgress(scrollRatio: _currentScrollRatio());
    });
  }

  void _handleKeyEvent(KeyEvent event, int chapterCount) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && _chapterIndex > 0) {
      _goToChapter(_chapterIndex - 1);
      return;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        _chapterIndex < chapterCount - 1) {
      _goToChapter(_chapterIndex + 1);
      return;
    }
    if (key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        key == LogicalKeyboardKey.equal) {
      _changeFontSize(1);
      return;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _changeFontSize(-1);
      return;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _changeFontSize(double delta) {
    final settings = _appController.settings;
    final fontSize = (settings.fontSize + delta).clamp(14.0, 30.0);
    return _appController.updateSettings(settings.copyWith(fontSize: fontSize));
  }

  Future<void> _restoreReadingPlace() async {
    if (!mounted) return;
    final story = _appController.storyById(widget.storyId);
    final ratio =
        widget.initialScrollRatio ??
        (story?.lastReadChapterIndex == _chapterIndex
            ? story?.lastReadScrollRatio ?? 0.0
            : 0.0);
    _isRestoringScroll = true;
    await _jumpToRatio(ratio);
    _isRestoringScroll = false;
    if (mounted) setState(() => _chapterProgress = _currentScrollRatio());
    await _saveProgress(scrollRatio: _currentScrollRatio());
  }

  Future<void> _jumpToRatio(double ratio) async {
    await Future<void>.delayed(Duration.zero);
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final offset = position.maxScrollExtent * ratio.clamp(0.0, 1.0);
    _scrollController.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
  }

  Future<void> _saveProgress({double? scrollRatio}) async {
    await _appController.updateReadingProgress(
      storyId: widget.storyId,
      chapterIndex: _chapterIndex,
      scrollRatio: scrollRatio ?? _currentScrollRatio(),
    );
  }

  double _currentScrollRatio() {
    if (!_scrollController.hasClients) return _chapterProgress;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return 0;
    return (_scrollController.offset / max).clamp(0.0, 1.0);
  }

  void _goToChapter(int index) {
    _saveScrollTimer?.cancel();
    setState(() {
      _chapterIndex = index;
      _chapterProgress = 0;
      _chromeVisible = true;
      _searchQuery = '';
      _searchMatches = [];
      _activeMatchIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _saveProgress(scrollRatio: 0);
    });
  }

  Future<void> _showBookmarkDialog({
    required String chapterTitle,
    required Bookmark? existingBookmark,
  }) async {
    final bookmark = existingBookmark;
    final noteController = TextEditingController(text: bookmark?.note);
    final result = await showDialog<_BookmarkDialogResult>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đánh dấu'),
        content: TextField(
          controller: noteController,
          maxLength: 180,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Ghi chú',
            hintText: 'Nhập ghi chú ngắn nếu muốn',
          ),
        ),
        actions: [
          if (bookmark != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_BookmarkDialogResult.delete),
              child: const Text('Xóa'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(_BookmarkDialogResult.save(noteController.text)),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (result == null || !mounted) return;

    if (result.shouldDelete && bookmark != null) {
      await _appController.deleteBookmark(bookmark.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa đánh dấu')));
      return;
    }

    await _appController.saveBookmark(
      bookmarkId: bookmark?.id,
      storyId: widget.storyId,
      chapterIndex: _chapterIndex,
      chapterTitle: chapterTitle,
      scrollRatio: _currentScrollRatio(),
      note: result.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu đánh dấu')));
  }

  Future<void> _showChapterSearch(String content) async {
    final queryController = TextEditingController(text: _searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tìm trong chương'),
        content: TextField(
          controller: queryController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nhập từ khóa'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(queryController.text),
            child: const Text('Tìm'),
          ),
        ],
      ),
    );
    queryController.dispose();
    if (query == null) return;

    final matches = _findMatches(content, query.trim());
    setState(() {
      _searchQuery = query.trim();
      _searchMatches = matches;
      _activeMatchIndex = 0;
      _chromeVisible = true;
    });
    if (matches.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không tìm thấy kết quả')));
      return;
    }
    _goToSearchMatch(0, content);
  }

  List<int> _findMatches(String content, String query) {
    if (query.isEmpty) return [];
    final lowerContent = content.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matches = <int>[];
    var start = 0;
    while (start < lowerContent.length) {
      final index = lowerContent.indexOf(lowerQuery, start);
      if (index == -1) break;
      matches.add(index);
      start = index + lowerQuery.length;
    }
    return matches;
  }

  void _goToSearchMatch(int index, String content) {
    if (_searchMatches.isEmpty) return;
    final nextIndex = index < 0
        ? _searchMatches.length - 1
        : index >= _searchMatches.length
        ? 0
        : index;
    setState(() => _activeMatchIndex = nextIndex);
    final ratio = content.isEmpty
        ? 0.0
        : _searchMatches[nextIndex] / content.length;
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToRatio(ratio));
  }

  void _showReaderSettings(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    if (isWide) {
      showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const _ReaderSettingsPanel(),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ReaderSettingsPanel(),
    );
  }
}

class _BookmarkDialogResult {
  const _BookmarkDialogResult._({this.note, this.shouldDelete = false});

  final String? note;
  final bool shouldDelete;

  static const delete = _BookmarkDialogResult._(shouldDelete: true);
  static _BookmarkDialogResult save(String note) =>
      _BookmarkDialogResult._(note: note);
}

class _SearchStatusBar extends StatelessWidget {
  const _SearchStatusBar({
    required this.query,
    required this.matchCount,
    required this.activeMatchIndex,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final String query;
  final int matchCount;
  final int activeMatchIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final label = matchCount == 0
        ? 'Không tìm thấy kết quả'
        : '${activeMatchIndex + 1}/$matchCount kết quả cho "$query"';
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
            IconButton(
              tooltip: 'Kết quả trước',
              onPressed: onPrevious,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Kết quả sau',
              onPressed: onNext,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Đóng tìm kiếm',
              onPressed: onClose,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderProgressBar extends StatelessWidget {
  const _ReaderProgressBar({
    required this.progress,
    required this.foreground,
    required this.background,
    required this.visible,
  });

  final double progress;
  final Color foreground;
  final Color background;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: visible ? 34 : 3,
      color: background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(progress * 100).round()}% chương',
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
              ),
            ),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: foreground.withValues(alpha: 0.12),
            color: foreground.withValues(alpha: 0.58),
          ),
        ],
      ),
    );
  }
}

class _ReaderNavigationBar extends StatelessWidget {
  const _ReaderNavigationBar({
    super.key,
    required this.background,
    required this.foreground,
    required this.chapterIndex,
    required this.chapterCount,
    required this.onBookmark,
    required this.isBookmarked,
    required this.onPrevious,
    required this.onNext,
  });

  final Color background;
  final Color foreground;
  final int chapterIndex;
  final int chapterCount;
  final VoidCallback onBookmark;
  final bool isBookmarked;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
              label: Text(narrow ? 'Trước' : 'Chương trước'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Đánh dấu',
                  onPressed: onBookmark,
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_add_outlined,
                    color: isBookmarked ? foreground : null,
                  ),
                ),
                Text(
                  '${chapterIndex + 1}/$chapterCount',
                  style: TextStyle(color: foreground, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              label: Text(narrow ? 'Sau' : 'Chương sau'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderSettingsPanel extends StatelessWidget {
  const _ReaderSettingsPanel();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.settings;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        shrinkWrap: true,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cài đặt đọc',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Chế độ tối'),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (value) => controller.updateSettings(
              settings.copyWith(
                themeMode: value ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Cỡ chữ: ${settings.fontSize.toStringAsFixed(0)}'),
          Slider(
            min: 14,
            max: 30,
            divisions: 16,
            value: settings.fontSize.clamp(14.0, 30.0),
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(fontSize: value)),
          ),
          Text('Giãn dòng: ${settings.lineHeight.toStringAsFixed(2)}'),
          Slider(
            min: 1.2,
            max: 2.2,
            divisions: 10,
            value: settings.lineHeight,
            onChanged: (value) =>
                controller.updateSettings(settings.copyWith(lineHeight: value)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: settings.fontFamily,
            decoration: const InputDecoration(labelText: 'Font chữ'),
            items: const [
              DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
              DropdownMenuItem(value: 'serif', child: Text('Serif')),
              DropdownMenuItem(value: 'monospace', child: Text('Monospace')),
            ],
            onChanged: (value) {
              if (value == null) return;
              controller.updateSettings(settings.copyWith(fontFamily: value));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReaderBackgroundMode>(
            initialValue: settings.backgroundMode == ReaderBackgroundMode.white
                ? ReaderBackgroundMode.paper
                : settings.backgroundMode,
            decoration: const InputDecoration(labelText: 'Màu nền đọc'),
            items: const [
              DropdownMenuItem(
                value: ReaderBackgroundMode.paper,
                child: Text('Mặc định'),
              ),
              DropdownMenuItem(
                value: ReaderBackgroundMode.sepia,
                child: Text('Vàng nhạt'),
              ),
              DropdownMenuItem(
                value: ReaderBackgroundMode.gray,
                child: Text('Xám'),
              ),
              DropdownMenuItem(
                value: ReaderBackgroundMode.black,
                child: Text('Đen'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              controller.updateSettings(
                settings.copyWith(backgroundMode: value),
              );
            },
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: controller.resetSettings,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset về mặc định'),
          ),
        ],
      ),
    );
  }
}
