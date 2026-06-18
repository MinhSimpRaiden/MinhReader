import '../../../data/local/local_database.dart';
import '../../reader/models/bookmark.dart';
import '../models/sync_result.dart';

abstract class SyncService {
  Future<SyncResult> uploadLocalData();

  Future<SyncResult> downloadRemoteData();

  Future<LocalDatabaseSnapshot> mergeLocalAndRemote({
    required LocalDatabaseSnapshot local,
    required LocalDatabaseSnapshot remote,
  });

  Future<DateTime?> getLastSyncTime();

  Future<void> enableSync();

  Future<void> disableSync();
}

List<Bookmark> mergeBookmarksById({
  required List<Bookmark> local,
  required List<Bookmark> remote,
}) {
  final merged = <String, Bookmark>{};
  for (final bookmark in local) {
    merged[bookmark.id] = bookmark;
  }
  for (final bookmark in remote) {
    final current = merged[bookmark.id];
    if (current == null || bookmark.createdAt.isAfter(current.createdAt)) {
      merged[bookmark.id] = bookmark;
    }
  }
  return merged.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
