enum SyncPhase {
  disabled,
  localOnly,
  cloudNotConfigured,
  syncing,
  success,
  failed,
}

class SyncStatus {
  const SyncStatus({required this.phase, this.lastSyncTime, this.message});

  final SyncPhase phase;
  final DateTime? lastSyncTime;
  final String? message;

  bool get isEnabled =>
      phase != SyncPhase.disabled && phase != SyncPhase.localOnly;

  static const localOnly = SyncStatus(
    phase: SyncPhase.localOnly,
    message: 'Chỉ dùng offline',
  );
}
