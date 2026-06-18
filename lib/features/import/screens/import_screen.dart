import 'package:flutter/material.dart';

import '../../comic/services/comic_import_service.dart';
import '../../library/models/story.dart';
import '../../library/providers/app_controller.dart';
import '../../library/screens/story_detail_screen.dart';
import '../services/epub_import_service.dart';
import '../services/txt_import_service.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _txtService = TxtImportService();
  final _epubService = EpubImportService();
  final _comicService = ComicImportService();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  _ImportDraft? _draft;
  bool _isProcessing = false;
  String? _loadingText;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(title: const Text('Nhập truyện')),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Chọn loại file',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'MinhReader chỉ nhập file hợp pháp trên thiết bị của bạn.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 760;
                        final cards = [
                          _ImportOptionCard(
                            icon: Icons.description_outlined,
                            title: 'Nhập TXT',
                            description:
                                'Phù hợp với truyện văn bản thuần. App tự tách chương hoặc chia phần.',
                            selected: draft?.sourceType == 'local_txt',
                            onTap: _isProcessing ? null : _pickTxtFile,
                          ),
                          _ImportOptionCard(
                            icon: Icons.menu_book_outlined,
                            title: 'Nhập EPUB',
                            description:
                                'Đọc metadata, danh sách chương và chuyển HTML thành text dễ đọc.',
                            selected: draft?.sourceType == 'local_epub',
                            onTap: _isProcessing ? null : _pickEpubFile,
                          ),
                          _ImportOptionCard(
                            icon: Icons.collections_outlined,
                            title: 'Nhập truyện tranh',
                            description:
                                'Chọn file CBZ/ZIP local, app giải nén ảnh và đọc theo kiểu lướt dọc.',
                            selected: draft?.sourceType == 'local_comic',
                            onTap: _isProcessing ? null : _pickComicFile,
                          ),
                        ];
                        if (!wide) {
                          return Column(
                            children: [
                              for (
                                var index = 0;
                                index < cards.length;
                                index++
                              ) ...[
                                if (index > 0) const SizedBox(height: 12),
                                cards[index],
                              ],
                            ],
                          );
                        }
                        return Row(
                          children: [
                            for (
                              var index = 0;
                              index < cards.length;
                              index++
                            ) ...[
                              if (index > 0) const SizedBox(width: 12),
                              Expanded(child: cards[index]),
                            ],
                          ],
                        );
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    if (draft != null) ...[
                      const SizedBox(height: 20),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draft.titleLabel,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _titleController,
                                decoration: const InputDecoration(
                                  labelText: 'Tên truyện',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _authorController,
                                decoration: const InputDecoration(
                                  labelText: 'Tác giả (tùy chọn)',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'File: ${draft.filePath}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (draft.chapterCountPreview != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Đã nhận diện ${draft.chapterCountPreview} chương',
                                  ),
                                ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _isProcessing ? null : _save,
                                icon: const Icon(Icons.library_add_outlined),
                                label: const Text('Lưu vào thư viện'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isProcessing)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.18),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(_loadingText ?? 'Đang xử lý...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTxtFile() async {
    await _runPick(
      loadingText: 'Đang xử lý file TXT...',
      action: () async {
        final picked = await _txtService.pickTxtFile();
        if (picked == null || !mounted) return;
        setState(() {
          _draft = _ImportDraft.txt(picked);
          _titleController.text = picked.defaultTitle;
          _authorController.clear();
        });
      },
    );
  }

  Future<void> _pickEpubFile() async {
    await _runPick(
      loadingText: 'Đang xử lý EPUB...',
      action: () async {
        final parsed = await _epubService.pickAndParseEpubFile();
        if (parsed == null || !mounted) return;
        setState(() {
          _draft = _ImportDraft.epub(parsed);
          _titleController.text = parsed.story.title;
          _authorController.text = parsed.story.author == 'Không rõ'
              ? ''
              : parsed.story.author;
        });
      },
    );
  }

  Future<void> _pickComicFile() async {
    await _runPick(
      loadingText: 'Đang xử lý truyện tranh...',
      action: () async {
        final parsed = await _comicService.pickAndParseComicFile();
        if (parsed == null || !mounted) return;
        setState(() {
          _draft = _ImportDraft.comic(parsed);
          _titleController.text = parsed.story.title;
          _authorController.clear();
        });
      },
    );
  }

  Future<void> _runPick({
    required String loadingText,
    required Future<void> Function() action,
  }) async {
    setState(() {
      _isProcessing = true;
      _loadingText = loadingText;
      _error = null;
    });
    try {
      await action();
    } on TxtImportException catch (error) {
      _showError(error.message);
    } on EpubImportException catch (error) {
      _showError(error.message);
    } on ComicImportException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể đọc file. Vui lòng thử lại với file khác.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _loadingText = null;
        });
      }
    }
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null) return;

    setState(() {
      _isProcessing = true;
      _loadingText = draft.loadingText;
      _error = null;
    });
    try {
      final controller = AppScope.of(context);
      final savedStory = await _saveDraft(controller, draft);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(draft.successText)));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => StoryDetailScreen(storyId: savedStory.id),
        ),
      );
    } on TxtImportException catch (error) {
      _showError(error.message);
    } on EpubImportException catch (error) {
      _showError(error.message);
    } on ComicImportException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Không thể lưu truyện. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _loadingText = null;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Story> _saveDraft(AppController controller, _ImportDraft draft) {
    if (draft.sourceType == 'local_comic') {
      final parsed = draft.toParsedComic(
        title: _titleController.text,
        author: _authorController.text,
      );
      return controller.addComicStory(parsed.story, parsed.chapters);
    }
    final parsed = draft.toParsedStory(
      title: _titleController.text,
      author: _authorController.text,
      txtService: _txtService,
    );
    return controller.addStory(parsed.story, parsed.chapters);
  }
}

class _ImportOptionCard extends StatelessWidget {
  const _ImportOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(description),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportDraft {
  const _ImportDraft({
    required this.sourceType,
    required this.filePath,
    this.txtStory,
    this.epubDraft,
    this.comicDraft,
  });

  factory _ImportDraft.txt(PickedTxtStory picked) {
    return _ImportDraft(
      sourceType: 'local_txt',
      filePath: picked.filePath,
      txtStory: picked,
    );
  }

  factory _ImportDraft.epub(ParsedEpubDraft parsed) {
    return _ImportDraft(
      sourceType: 'local_epub',
      filePath: parsed.filePath,
      epubDraft: parsed,
    );
  }

  factory _ImportDraft.comic(ParsedComicDraft parsed) {
    return _ImportDraft(
      sourceType: 'local_comic',
      filePath: parsed.filePath,
      comicDraft: parsed,
    );
  }

  final String sourceType;
  final String filePath;
  final PickedTxtStory? txtStory;
  final ParsedEpubDraft? epubDraft;
  final ParsedComicDraft? comicDraft;

  int? get chapterCountPreview =>
      epubDraft?.chapters.length ?? comicDraft?.chapters.length;

  String get titleLabel => switch (sourceType) {
    'local_epub' => 'Thông tin EPUB',
    'local_comic' => 'Thông tin truyện tranh',
    _ => 'Thông tin TXT',
  };

  String get loadingText => switch (sourceType) {
    'local_epub' => 'Đang xử lý EPUB...',
    'local_comic' => 'Đang xử lý truyện tranh...',
    _ => 'Đang xử lý file TXT...',
  };

  String get successText => sourceType == 'local_comic'
      ? 'Đã nhập truyện tranh thành công'
      : 'Đã lưu vào thư viện';

  ParsedComicDraft toParsedComic({
    required String title,
    required String author,
  }) {
    final parsed = comicDraft!;
    final story = parsed.story.copyWith(
      title: title.trim().isEmpty ? parsed.story.title : title.trim(),
      author: author.trim().isEmpty ? 'Không rõ' : author.trim(),
    );
    return ParsedComicDraft(
      story: story,
      chapters: parsed.chapters,
      filePath: parsed.filePath,
    );
  }

  ParsedStory toParsedStory({
    required String title,
    required String author,
    required TxtImportService txtService,
  }) {
    if (sourceType == 'local_txt') {
      final picked = txtStory!;
      return txtService.parse(
        title: title,
        author: author,
        content: picked.content,
      );
    }

    final parsed = epubDraft!;
    final story = parsed.story.copyWith(
      title: title.trim().isEmpty ? parsed.story.title : title.trim(),
      author: author.trim().isEmpty ? 'Không rõ' : author.trim(),
    );
    return ParsedStory(story: story, chapters: parsed.chapters);
  }
}
