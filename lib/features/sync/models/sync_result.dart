import 'sync_conflict.dart';
import 'sync_status.dart';

class SyncResult {
  const SyncResult({
    required this.status,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.conflicts = const [],
  });

  final SyncStatus status;
  final int uploadedCount;
  final int downloadedCount;
  final List<SyncConflict> conflicts;

  bool get isSuccess => status.phase == SyncPhase.success;
}
