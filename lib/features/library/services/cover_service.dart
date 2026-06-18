import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CoverException implements Exception {
  const CoverException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CoverService {
  CoverService({this.directoryProvider});

  final Future<Directory> Function()? directoryProvider;

  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  Future<Directory> coversDirectory() async {
    final base = directoryProvider == null
        ? await getApplicationDocumentsDirectory()
        : await directoryProvider!();
    final directory = Directory('${base.path}${Platform.pathSeparator}covers');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<String?> pickAndSaveCover(String storyId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowedExtensions.toList(),
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final sourcePath = result.files.single.path!;
    final extension = _extensionOf(sourcePath);
    if (!_allowedExtensions.contains(extension)) {
      throw const CoverException('Không thể đọc ảnh bìa');
    }

    try {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw const CoverException('Không thể đọc ảnh bìa');
      }
      final directory = await coversDirectory();
      final target = File(
        '${directory.path}${Platform.pathSeparator}${_safeName(storyId)}.$extension',
      );
      await source.copy(target.path);
      return target.path;
    } on CoverException {
      rethrow;
    } catch (_) {
      throw const CoverException('Không thể đọc ảnh bìa');
    }
  }

  Future<String?> saveEpubCover({
    required String storyId,
    required img.Image? coverImage,
  }) async {
    if (coverImage == null) return null;
    try {
      final directory = await coversDirectory();
      final target = File(
        '${directory.path}${Platform.pathSeparator}${_safeName(storyId)}.png',
      );
      await target.writeAsBytes(img.encodePng(coverImage), flush: true);
      return target.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteManagedCover(String? path) async {
    if (path == null || !await isManagedCoverPath(path)) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Cover cleanup must never block story deletion.
    }
  }

  Future<bool> isManagedCoverPath(String path) async {
    final directory = await coversDirectory();
    final coverRoot = _normalize(directory.path);
    final target = _normalize(File(path).absolute.path);
    return target == coverRoot || target.startsWith('$coverRoot/');
  }

  bool canReadCover(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  static String _extensionOf(String path) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return cleaned.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : cleaned;
  }

  static String _normalize(String path) => path.replaceAll('\\', '/');
}
