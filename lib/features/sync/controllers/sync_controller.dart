import 'package:flutter/foundation.dart';

import '../models/sync_status.dart';
import '../services/local_only_sync_service.dart';
import '../services/sync_service.dart';

class SyncController extends ChangeNotifier {
  SyncController(this._syncService);

  final SyncService _syncService;

  SyncStatus _status = SyncStatus.localOnly;
  bool _isBusy = false;

  SyncStatus get status => _status;
  bool get isBusy => _isBusy;

  Future<void> load() async {
    _status = SyncStatus(
      phase: SyncPhase.localOnly,
      lastSyncTime: await _syncService.getLastSyncTime(),
      message: 'Chỉ dùng offline',
    );
    notifyListeners();
  }

  Future<void> enableSync() async {
    await _syncService.enableSync();
    _status = _statusFromService();
    notifyListeners();
  }

  Future<void> disableSync() async {
    await _syncService.disableSync();
    _status = SyncStatus.localOnly;
    notifyListeners();
  }

  Future<void> syncNow() async {
    _isBusy = true;
    _status = SyncStatus(
      phase: SyncPhase.syncing,
      lastSyncTime: _status.lastSyncTime,
      message: 'Đang đồng bộ',
    );
    notifyListeners();
    try {
      await _syncService.uploadLocalData();
      await _syncService.downloadRemoteData();
      _status = _statusFromService();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  SyncStatus _statusFromService() {
    if (_syncService is LocalOnlySyncService) {
      return _syncService.status;
    }
    return SyncStatus(
      phase: SyncPhase.success,
      lastSyncTime: DateTime.now(),
      message: 'Đã đồng bộ',
    );
  }
}
