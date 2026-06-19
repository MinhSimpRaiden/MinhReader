import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minh_reader/features/plugins/models/plugin_runtime_models.dart';
import 'package:minh_reader/features/plugins/screens/plugin_network_comic_reader_screen.dart';
import 'package:minh_reader/features/plugins/services/plugin_comic_image_safety.dart';
import 'package:minh_reader/features/plugins/services/plugin_runtime_service.dart';

void main() {
  test('PluginComicImageSafety chỉ chấp nhận URL http/https', () {
    expect(
      PluginComicImageSafety.isSupportedImageUrl(
        'https://example.com/page.jpg',
      ),
      isTrue,
    );
    expect(
      PluginComicImageSafety.isSupportedImageUrl('http://example.com/page.jpg'),
      isTrue,
    );
    expect(
      PluginComicImageSafety.isSupportedImageUrl('file:///tmp/a.jpg'),
      isFalse,
    );
    expect(
      PluginComicImageSafety.isSupportedImageUrl('javascript:alert(1)'),
      isFalse,
    );
    expect(
      PluginComicImageSafety.isSupportedImageUrl('/relative/page.jpg'),
      isFalse,
    );
  });

  testWidgets(
    'Network comic reader hiển thị empty state khi chương chưa có ảnh',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PluginNetworkComicReaderScreen(
            pluginId: 'plugin',
            storyId: 'story',
            storyTitle: 'Truyện tranh test',
            chapters: _chapters,
            initialChapterIndex: 0,
            runtimeService: _FakeRuntimeService(const []),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chương này chưa có ảnh'), findsOneWidget);
    },
  );

  testWidgets(
    'Network comic reader hiển thị placeholder cho URL không hợp lệ',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PluginNetworkComicReaderScreen(
            pluginId: 'plugin',
            storyId: 'story',
            storyTitle: 'Truyện tranh test',
            chapters: _chapters,
            initialChapterIndex: 0,
            runtimeService: _FakeRuntimeService(const ['file:///tmp/page.jpg']),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Không thể tải ảnh'), findsOneWidget);
      expect(find.textContaining('URL ảnh không hợp lệ'), findsOneWidget);
    },
  );
}

const _chapters = [
  PluginRuntimeChapter(id: 'chapter_1', title: 'Chương 1', index: 0),
];

class _FakeRuntimeService extends PluginRuntimeService {
  _FakeRuntimeService(this.images);

  final List<String> images;

  @override
  Future<PluginComicChapterImages> getComicChapterImages(
    String pluginId,
    String chapterId,
  ) async {
    return PluginComicChapterImages(
      id: chapterId,
      title: 'Chương 1',
      index: 0,
      images: images,
    );
  }
}
