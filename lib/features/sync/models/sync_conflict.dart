class SyncConflict {
  const SyncConflict({
    required this.entityType,
    required this.entityId,
    required this.localUpdatedAt,
    required this.remoteUpdatedAt,
    required this.resolution,
  });

  final String entityType;
  final String entityId;
  final DateTime? localUpdatedAt;
  final DateTime? remoteUpdatedAt;
  final String resolution;
}
