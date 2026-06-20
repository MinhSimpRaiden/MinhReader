import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:minh_reader/features/plugins/services/plugin_manifest_fetcher.dart';
import 'package:minh_reader/features/plugins/services/plugin_repository.dart';
import 'package:minh_reader/features/plugins/services/plugin_storage.dart';
import 'package:minh_reader/features/plugins/services/plugin_url_import_service.dart';
import 'package:minh_reader/features/plugins/services/plugin_url_validator.dart';

void main() {
  group('PluginUrlValidator', () {
    test('accept http và https', () {
      final validator = PluginUrlValidator();
      expect(validator.validate('https://example.com/plugin.json'), isNull);
      expect(validator.validate('http://example.com/plugin.json'), isNull);
      expect(
        validator.validate('https://example.com/minhreader_plugin.json'),
        isNull,
      );
    });

    test('reject javascript/data/file/ftp/about/chrome', () {
      final validator = PluginUrlValidator();
      for (final url in [
        'javascript:alert(1)',
        'data:text/plain,hello',
        'file:///tmp/plugin.json',
        'ftp://example.com/plugin.json',
        'about:blank',
        'chrome://settings',
      ]) {
        expect(
          validator.validate(url),
          PluginUrlValidator.invalidUrlMessage,
          reason: url,
        );
      }
    });

    test('reject URL rỗng', () {
      expect(
        PluginUrlValidator().validate('   '),
        PluginUrlValidator.invalidUrlMessage,
      );
    });
  });

  group('PluginManifestFetcher', () {
    test('fetch valid JSON plugin bằng mock client', () async {
      final fetcher = PluginManifestFetcher(
        client: MockClient((request) async {
          expect(
            request.headers.values.any(
              (value) => value.toLowerCase() == 'application/json',
            ),
            isTrue,
          );
          expect(request.headers.containsKey('cookie'), isFalse);
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response.bytes(
            utf8.encode(jsonEncode(_validTextPlugin())),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final json = await fetcher.fetchManifestJson(
        'https://example.com/plugin.json',
      );

      expect(json['id'], 'sample_test_text');
    });

    test('reject non-JSON response', () async {
      final fetcher = PluginManifestFetcher(
        client: MockClient(
          (_) async => http.Response('<html>not json</html>', 200),
        ),
      );

      expect(
        () => fetcher.fetchManifestJson('https://example.com/plugin.json'),
        throwsA(
          isA<PluginManifestFetchException>().having(
            (error) => error.message,
            'message',
            PluginManifestFetcher.invalidJsonMessage,
          ),
        ),
      );
    });

    test('reject non-2xx response', () async {
      final fetcher = PluginManifestFetcher(
        client: MockClient((_) async => http.Response('{}', 404)),
      );

      expect(
        () => fetcher.fetchManifestJson('https://example.com/plugin.json'),
        throwsA(
          isA<PluginManifestFetchException>().having(
            (error) => error.message,
            'message',
            PluginManifestFetcher.fetchFailedMessage,
          ),
        ),
      );
    });
  });

  group('PluginUrlImportService', () {
    test('fetchAndValidate trả manifest hợp lệ với installUrl', () async {
      final service = PluginUrlImportService(
        fetcher: PluginManifestFetcher(
          client: MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(jsonEncode(_validTextPlugin())),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      );

      final result = await service.fetchAndValidate(
        'https://example.com/plugin.json',
      );

      expect(result.manifest.id, 'sample_test_text');
      expect(result.manifest.installUrl, 'https://example.com/plugin.json');
      expect(result.manifest.sourceUrl, 'https://example.com/plugin.json');
    });

    test('reject invalid manifest từ URL', () async {
      final invalid = _validTextPlugin()..remove('id');
      final service = PluginUrlImportService(
        fetcher: PluginManifestFetcher(
          client: MockClient(
            (_) async => http.Response.bytes(
              utf8.encode(jsonEncode(invalid)),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      );

      expect(
        () => service.fetchAndValidate('https://example.com/plugin.json'),
        throwsA(
          isA<PluginUrlImportException>().having(
            (error) => error.message,
            'message',
            'Plugin không hợp lệ',
          ),
        ),
      );
    });

    test('reject URL không hợp lệ trước khi fetch', () async {
      final service = PluginUrlImportService(
        fetcher: PluginManifestFetcher(
          client: MockClient((_) async {
            fail('Không được gọi fetch khi URL sai');
          }),
        ),
      );

      expect(
        () => service.fetchAndValidate('javascript:alert(1)'),
        throwsA(
          isA<PluginUrlImportException>().having(
            (error) => error.message,
            'message',
            PluginUrlValidator.invalidUrlMessage,
          ),
        ),
      );
    });
  });

  test('install plugin from URL lưu installUrl/sourceUrl', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_plugin_url_');
    addTearDown(() => tempDir.delete(recursive: true));
    final repository = PluginRepository(
      storage: PluginStorage(directoryProvider: () async => tempDir),
    );
    final service = PluginUrlImportService(
      fetcher: PluginManifestFetcher(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode(_validTextPlugin())),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );

    final result = await service.fetchAndValidate(
      'https://example.com/plugin.json',
    );
    await repository.installPlugin(result.manifest);

    final installed = await repository.getInstalledPlugins();
    expect(installed, hasLength(1));
    expect(installed.single.installUrl, 'https://example.com/plugin.json');
    expect(installed.single.sourceUrl, 'https://example.com/plugin.json');
  });

  test('update existing plugin trùng id giữ enabled state', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_plugin_upd_');
    addTearDown(() => tempDir.delete(recursive: true));
    final repository = PluginRepository(
      storage: PluginStorage(directoryProvider: () async => tempDir),
    );
    final service = PluginUrlImportService(
      fetcher: PluginManifestFetcher(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode(_validTextPlugin())),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );

    final first = await service.fetchAndValidate(
      'https://example.com/plugin-v1.json',
    );
    await repository.installPlugin(first.manifest);
    await repository.disablePlugin('sample_test_text');

    final updatedJson = _validTextPlugin()
      ..['version'] = '2.0.0'
      ..['description'] = 'Updated from URL';
    final second = await PluginUrlImportService(
      fetcher: PluginManifestFetcher(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode(updatedJson)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    ).fetchAndValidate('https://example.com/plugin-v2.json');

    await repository.installPlugin(
      second.manifest,
      preserveEnabledState: true,
    );

    final installed = await repository.getInstalledPlugins();
    expect(installed, hasLength(1));
    expect(installed.single.version, '2.0.0');
    expect(installed.single.isEnabled, isFalse);
    expect(installed.single.installUrl, 'https://example.com/plugin-v2.json');
  });

  test('file import plugin cũ vẫn hoạt động', () async {
    final tempDir = await Directory.systemTemp.createTemp('minh_plugin_file_');
    addTearDown(() => tempDir.delete(recursive: true));
    final pluginFile = File(
      '${tempDir.path}${Platform.pathSeparator}plugin.json',
    );
    await pluginFile.writeAsString(jsonEncode(_validTextPlugin()));
    final repository = PluginRepository(
      storage: PluginStorage(directoryProvider: () async => tempDir),
    );

    final manifest = await repository.installFromFile(pluginFile);

    expect(manifest.id, 'sample_test_text');
    expect(manifest.installUrl, isNull);
    expect(await repository.getInstalledPlugins(), hasLength(1));
  });

  test('Validator security cũ vẫn chặn script từ JSON URL', () async {
    final json = _validTextPlugin()..['script'] = 'bad';
    final service = PluginUrlImportService(
      fetcher: PluginManifestFetcher(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode(json)),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      ),
    );

    expect(
      () => service.fetchAndValidate('https://example.com/plugin.json'),
      throwsA(isA<PluginUrlImportException>()),
    );
  });
}

Map<String, dynamic> _validTextPlugin() => {
  'id': 'sample_test_text',
  'name': 'Sample Test Text',
  'version': '1.0.0',
  'author': 'MinhReader Demo',
  'description': 'Demo text plugin',
  'contentType': 'text',
  'sourceType': 'static_json',
  'license': 'CC0-1.0',
  'language': 'vi',
  'stories': [
    {
      'id': 'story-1',
      'title': 'Ngọn đèn',
      'author': 'MinhReader Demo',
      'description': 'Demo',
      'contentType': 'text',
      'chapters': [
        {
          'id': 'c1',
          'title': 'Chương 1',
          'index': 0,
          'contentKind': 'text',
          'content': 'Một ngọn đèn nhỏ trong đêm.',
        },
      ],
    },
  ],
};
