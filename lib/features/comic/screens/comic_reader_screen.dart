import 'dart:io';

import 'package:flutter/material.dart';

import '../../library/providers/app_controller.dart';

class ComicReaderScreen extends StatefulWidget {
  const ComicReaderScreen({
    super.key,
    required this.storyId,
    required this.initialChapterIndex,
    this.initialScrollRatio = 0,
  });

  final String storyId;
  final int initialChapterIndex;
  final double initialScrollRatio;

  @override
  State<ComicReaderScreen> createState() => _ComicReaderScreenState();
}

class _ComicReaderScreenState extends State<ComicReaderScreen> {
  final _scrollController = ScrollController();
  late int _chapterIndex;
  double _scrollRatio = 0;
  bool _restoredScroll = false;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.initialChapterIndex;
    _scrollRatio = widget.initialScrollRatio.clamp(0.0, 1.0);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final story = controller.storyById(widget.storyId);
    final chapters = controller.comicChaptersFor(widget.storyId);

    if (story == null || chapters.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Không tìm thấy truyện tranh')),
      );
    }

    _chapterIndex = _chapterIndex.clamp(0, chapters.length - 1);
    final chapter = chapters[_chapterIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreScroll());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(chapter.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('${(_scrollRatio * 100).round()}%'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _scrollRatio, minHeight: 3),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: chapter.imagePaths.length,
              itemBuilder: (context, index) {
                return _ComicPage(imagePath: chapter.imagePaths[index]);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: ColoredBox(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _chapterIndex <= 0
                            ? null
                            : () => _goToChapter(_chapterIndex - 1),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Chương trước'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _chapterIndex >= chapters.length - 1
                            ? null
                            : () => _goToChapter(_chapterIndex + 1),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Chương sau'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final ratio = max <= 0
        ? 0.0
        : (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((ratio - _scrollRatio).abs() < 0.01) return;
    setState(() => _scrollRatio = ratio);
  }

  void _restoreScroll() {
    if (_restoredScroll || !_scrollController.hasClients) return;
    _restoredScroll = true;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    _scrollController.jumpTo((max * widget.initialScrollRatio).clamp(0.0, max));
  }

  Future<void> _goToChapter(int chapterIndex) async {
    await _saveProgress();
    setState(() {
      _chapterIndex = chapterIndex;
      _scrollRatio = 0;
      _restoredScroll = true;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    await _saveProgress(markRead: true);
  }

  Future<void> _saveProgress({bool markRead = true}) {
    return AppScope.of(context).updateComicReadingProgress(
      storyId: widget.storyId,
      chapterIndex: _chapterIndex,
      scrollRatio: _scrollRatio,
      markRead: markRead,
    );
  }
}

class _ComicPage extends StatelessWidget {
  const _ComicPage({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    if (!file.existsSync()) {
      return const _ComicPageError();
    }
    return Image.file(
      file,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        );
      },
      errorBuilder: (_, _, _) => const _ComicPageError(),
    );
  }
}

class _ComicPageError extends StatelessWidget {
  const _ComicPageError();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.all(8),
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Text(
        'Không thể đọc ảnh',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
