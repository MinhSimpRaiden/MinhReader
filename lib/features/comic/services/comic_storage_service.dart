import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ComicStorageService {
  ComicStorageService({Future<Directory> Function()? directoryProvider})
    : _directoryProvider =
          directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<Directory> comicsRootDirectory() async {
    final base = await _directoryProvider();
    final directory = Directory('${base.path}${Platform.pathSeparator}comics');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> storyDirectory(String storyId) async {
    final root = await comicsRootDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}$storyId',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> deleteStoryDirectory(String storyId) async {
    try {
      final root = await comicsRootDirectory();
      final target = Directory('${root.path}${Platform.pathSeparator}$storyId');
      final normalizedRoot = _normalize(root.absolute.path);
      final normalizedTarget = _normalize(target.absolute.path);
      if (!normalizedTarget.startsWith('$normalizedRoot/')) return;
      if (await target.exists()) {
        await target.delete(recursive: true);
      }
    } catch (_) {
      // Comic file cleanup must never block deleting the library item.
    }
  }

  static String _normalize(String path) => path.replaceAll('\\', '/');
}
