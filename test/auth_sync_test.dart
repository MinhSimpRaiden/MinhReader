import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/data/local/local_database.dart';
import 'package:minh_reader/features/account/services/auth_service.dart';
import 'package:minh_reader/features/account/services/local_mock_auth_service.dart';
import 'package:minh_reader/features/reader/models/bookmark.dart';
import 'package:minh_reader/features/settings/models/reading_settings.dart';
import 'package:minh_reader/features/sync/models/sync_status.dart';
import 'package:minh_reader/features/sync/services/local_only_sync_service.dart';
import 'package:minh_reader/features/sync/services/sync_service.dart';

void main() {
  group('LocalMockAuthService', () {
    test('đăng nhập và đăng xuất mock auth', () async {
      final auth = LocalMockAuthService();

      final user = await auth.signInWithEmailAndPassword(
        email: 'reader@example.com',
        password: '123456',
      );

      expect(user.email, 'reader@example.com');
      expect(await auth.isSignedIn(), isTrue);

      await auth.signOut();

      expect(await auth.currentUser(), isNull);
      expect(await auth.isSignedIn(), isFalse);
    });

    test('email không hợp lệ báo AuthException', () {
      final auth = LocalMockAuthService();

      expect(
        () => auth.signInWithEmailAndPassword(
          email: 'reader',
          password: '123456',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('LocalOnlySyncService', () {
    test('sync status local-only khi chưa bật cloud', () async {
      final sync = LocalOnlySyncService();

      expect(sync.status.phase, SyncPhase.localOnly);
      expect(sync.status.message, 'Chỉ dùng offline');
    });

    test(
      'bật sync khi chưa cấu hình cloud trả về cloudNotConfigured',
      () async {
        final sync = LocalOnlySyncService();

        await sync.enableSync();

        expect(sync.status.phase, SyncPhase.cloudNotConfigured);
        expect(sync.status.message, 'Cloud chưa được cấu hình');
      },
    );

    test('merge bookmarks theo id, ưu tiên bản mới hơn', () async {
      final older = DateTime(2026, 6, 18, 9, 0);
      final newer = DateTime(2026, 6, 18, 10, 0);
      final local = _bookmark(
        id: 'bookmark-1',
        note: 'local',
        createdAt: older,
      );
      final remote = _bookmark(
        id: 'bookmark-1',
        note: 'remote',
        createdAt: newer,
      );

      final merged = mergeBookmarksById(local: [local], remote: [remote]);

      expect(merged, hasLength(1));
      expect(merged.single.note, 'remote');
    });

    test('mergeLocalAndRemote vẫn giữ stories local là nguồn chính', () async {
      final sync = LocalOnlySyncService();
      final local = LocalDatabaseSnapshot(
        stories: const [],
        chapters: const [],
        bookmarks: [_bookmark(id: 'local-only')],
        readingSettings: ReadingSettings.defaults,
      );
      final remote = LocalDatabaseSnapshot(
        stories: const [],
        chapters: const [],
        bookmarks: [_bookmark(id: 'remote-only')],
        readingSettings: ReadingSettings.defaults.copyWith(fontSize: 24),
      );

      final merged = await sync.mergeLocalAndRemote(
        local: local,
        remote: remote,
      );

      expect(merged.bookmarks.map((bookmark) => bookmark.id), {
        'local-only',
        'remote-only',
      });
      expect(
        merged.readingSettings.fontSize,
        ReadingSettings.defaults.fontSize,
      );
    });
  });
}

Bookmark _bookmark({required String id, String? note, DateTime? createdAt}) {
  return Bookmark(
    id: id,
    storyId: 'story-1',
    chapterIndex: 0,
    chapterTitle: 'Chương 1',
    scrollRatio: 0.5,
    createdAt: createdAt ?? DateTime(2026, 6, 18, 9, 0),
    note: note,
  );
}
