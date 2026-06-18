import '../../../data/local/local_database.dart';
import '../models/sync_result.dart';
import '../models/sync_status.dart';
import 'sync_service.dart';

class LocalOnlySyncService implements SyncService {
  DateTime? _lastSyncTime;
  bool _enabled = false;

  SyncStatus get status => SyncStatus(
    phase: _enabled ? SyncPhase.cloudNotConfigured : SyncPhase.localOnly,
    lastSyncTime: _lastSyncTime,
    message: _enabled ? 'Cloud chưa được cấu hình' : 'Chỉ dùng offline',
  );

  @override
  Future<SyncResult> uploadLocalData() async {
    _lastSyncTime = DateTime.now();
    return SyncResult(status: status);
  }

  @override
  Future<SyncResult> downloadRemoteData() async {
    _lastSyncTime = DateTime.now();
    return SyncResult(status: status);
  }

  @override
  Future<LocalDatabaseSnapshot> mergeLocalAndRemote({
    required LocalDatabaseSnapshot local,
    required LocalDatabaseSnapshot remote,
  }) async {
    return LocalDatabaseSnapshot(
      stories: local.stories,
      chapters: local.chapters,
      bookmarks: mergeBookmarksById(
        local: local.bookmarks,
        remote: remote.bookmarks,
      ),
      readingSettings: local.readingSettings,
      dataVersion: LocalDatabase.currentDataVersion,
    );
  }

  @override
  Future<DateTime?> getLastSyncTime() async => _lastSyncTime;

  @override
  Future<void> enableSync() async {
    _enabled = true;
  }

  @override
  Future<void> disableSync() async {
    _enabled = false;
  }
}
