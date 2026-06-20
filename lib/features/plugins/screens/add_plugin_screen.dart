import 'package:flutter/material.dart';

import '../models/plugin_manifest.dart';
import '../services/plugin_repository.dart';
import '../services/plugin_url_import_service.dart';
import '../services/plugin_validator.dart';

class AddPluginScreen extends StatefulWidget {
  const AddPluginScreen({super.key, required this.repository});

  final PluginRepository repository;

  @override
  State<AddPluginScreen> createState() => _AddPluginScreenState();
}

class _AddPluginScreenState extends State<AddPluginScreen> {
  final _urlController = TextEditingController();
  final _urlImportService = PluginUrlImportService();
  PluginManifest? _preview;
  String? _previewSourceUrl;
  String? _error;
  bool _isBusy = false;
  bool _showUrlForm = false;
  String? _busyMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm plugin')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Plugin nguồn truyện',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'MinhReader chỉ chấp nhận plugin dạng cấu hình JSON an toàn, không chạy mã thực thi.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _pickPluginFile,
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Chọn file plugin JSON'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _openUrlForm,
                      icon: const Icon(Icons.link_outlined),
                      label: const Text('Dán URL plugin'),
                    ),
                  ],
                ),
                if (_showUrlForm) ...[
                  const SizedBox(height: 20),
                  _UrlImportForm(
                    controller: _urlController,
                    isBusy: _isBusy,
                    onFetch: _fetchPluginFromUrl,
                    onCancel: _closeUrlForm,
                  ),
                ],
                if (_isBusy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(_busyMessage ?? 'Đang kiểm tra plugin...'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_preview != null) ...[
                  const SizedBox(height: 20),
                  _PluginPreviewCard(
                    plugin: _preview!,
                    sourceUrl: _previewSourceUrl,
                    onCancel: () => setState(() {
                      _preview = null;
                      _previewSourceUrl = null;
                    }),
                    onInstall: _installPreview,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openUrlForm() {
    setState(() {
      _showUrlForm = true;
      _error = null;
      _preview = null;
      _previewSourceUrl = null;
    });
  }

  void _closeUrlForm() {
    setState(() {
      _showUrlForm = false;
      _urlController.clear();
      _error = null;
    });
  }

  Future<void> _pickPluginFile() async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Đang kiểm tra plugin...';
      _error = null;
      _preview = null;
      _previewSourceUrl = null;
      _showUrlForm = false;
    });
    try {
      final manifest = await widget.repository.pickAndReadPlugin();
      if (!mounted || manifest == null) return;
      setState(() => _preview = manifest);
      _showMessage('Plugin hợp lệ');
    } on PluginValidationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showMessage('Plugin không hợp lệ');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'File này không phải plugin MinhReader hợp lệ');
      _showMessage('Plugin không hợp lệ');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _fetchPluginFromUrl() async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Đang tải plugin...';
      _error = null;
      _preview = null;
      _previewSourceUrl = null;
    });
    try {
      final result = await _urlImportService.fetchAndValidate(
        _urlController.text,
      );
      if (!mounted) return;
      setState(() {
        _preview = result.manifest;
        _previewSourceUrl = result.sourceUrl;
      });
      _showMessage('Plugin hợp lệ');
    } on PluginUrlImportException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không thể tải plugin từ URL');
      _showMessage('Không thể tải plugin từ URL');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _installPreview() async {
    final plugin = _preview;
    if (plugin == null) return;

    final existing = await widget.repository.findInstalled(plugin.id);
    if (!mounted) return;
    if (existing != null) {
      final shouldUpdate = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Plugin đã tồn tại'),
          content: const Text(
            'Plugin này đã tồn tại. Bạn muốn cập nhật không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cập nhật plugin'),
            ),
          ],
        ),
      );
      if (shouldUpdate != true || !mounted) return;
      await _savePlugin(plugin, isUpdate: true);
      return;
    }

    await _savePlugin(plugin, isUpdate: false);
  }

  Future<void> _savePlugin(PluginManifest plugin, {required bool isUpdate}) async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Đang cài plugin...';
    });
    try {
      await widget.repository.installPlugin(
        plugin,
        preserveEnabledState: isUpdate,
      );
      if (!mounted) return;
      _showMessage(isUpdate ? 'Đã cập nhật plugin' : 'Đã cài plugin');
      Navigator.of(context).pop(true);
    } on PluginValidationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UrlImportForm extends StatelessWidget {
  const _UrlImportForm({
    required this.controller,
    required this.isBusy,
    required this.onFetch,
    required this.onCancel,
  });

  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onFetch;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dán URL plugin',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !isBusy,
              decoration: const InputDecoration(
                labelText: 'Nhập URL plugin JSON',
                hintText: 'https://example.com/minhreader_plugin.json',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isBusy) onFetch();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(onPressed: isBusy ? null : onCancel, child: const Text('Hủy')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: isBusy ? null : onFetch,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Tải plugin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PluginPreviewCard extends StatelessWidget {
  const _PluginPreviewCard({
    required this.plugin,
    required this.onCancel,
    required this.onInstall,
    this.sourceUrl,
  });

  final PluginManifest plugin;
  final String? sourceUrl;
  final VoidCallback onCancel;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final license = plugin.license.trim().isEmpty
        ? 'Plugin chưa khai báo giấy phép. Chỉ sử dụng nếu bạn có quyền truy cập nguồn này.'
        : plugin.license;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plugin hợp lệ',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Tên plugin', value: plugin.name),
            _InfoRow(label: 'Version', value: plugin.version),
            _InfoRow(label: 'Tác giả', value: plugin.author),
            _InfoRow(label: 'Mô tả', value: plugin.description),
            _InfoRow(label: 'Loại nội dung', value: _contentLabel(plugin)),
            _InfoRow(label: 'Nguồn dữ liệu', value: plugin.sourceType),
            if (sourceUrl != null && sourceUrl!.trim().isNotEmpty)
              _InfoRow(label: 'URL nguồn plugin', value: sourceUrl!),
            _InfoRow(label: 'Giấy phép', value: license),
            const SizedBox(height: 12),
            const Text(
              'MinhReader chỉ chấp nhận plugin dạng cấu hình JSON an toàn, không chạy mã thực thi.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(onPressed: onCancel, child: const Text('Hủy')),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.extension_outlined),
                  label: const Text('Cài plugin'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _contentLabel(PluginManifest plugin) {
    return switch (plugin.contentType) {
      'comic' => 'Truyện tranh',
      'mixed' => 'Hỗn hợp',
      _ => 'Truyện chữ',
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? 'Chưa khai báo' : value)),
        ],
      ),
    );
  }
}
