import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../../../data/local/local_database.dart';

class BackupResult {
  const BackupResult({required this.path, required this.usedFallbackLocation});

  final String path;
  final bool usedFallbackLocation;
}

class RestoreResult {
  const RestoreResult({required this.automaticBackupPath});

  final String automaticBackupPath;
}

class BackupService {
  BackupService({LocalDatabase? database})
    : _database = database ?? LocalDatabase();

  final LocalDatabase _database;

  Future<BackupResult> exportBackup() async {
    final snapshot = await _database.read();
    final fileName = LocalDatabase.backupFileName();
    String? selectedPath;
    try {
      selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Xuất bản sao lưu',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (_) {
      selectedPath = null;
    }

    final fallbackDirectory = await _database.documentsDirectory();
    final path =
        selectedPath ??
        '${fallbackDirectory.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoderWithIndent().convert(
        LocalDatabase.snapshotToJson(snapshot),
      ),
      flush: true,
    );

    return BackupResult(
      path: file.path,
      usedFallbackLocation: selectedPath == null,
    );
  }

  Future<RestoreResult?> pickAndRestoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return null;

    final sourceFile = File(result.files.single.path!);
    if (!sourceFile.path.toLowerCase().endsWith('.json')) {
      throw const BackupValidationException('File sao lưu không hợp lệ');
    }
    try {
      final raw = await sourceFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupValidationException('File sao lưu không hợp lệ');
      }
      final snapshot = LocalDatabase.snapshotFromJson(decoded);
      final automaticBackup = await _database.createAutomaticBackup();
      await _database.write(snapshot);
      return RestoreResult(automaticBackupPath: automaticBackup.path);
    } catch (error) {
      if (error is BackupValidationException) rethrow;
      throw const BackupValidationException('Không thể khôi phục dữ liệu');
    }
  }

  Future<String> localDataPath() async {
    return (await _database.file()).path;
  }
}

class JsonEncoderWithIndent {
  const JsonEncoderWithIndent();

  String convert(Object? value) {
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}
