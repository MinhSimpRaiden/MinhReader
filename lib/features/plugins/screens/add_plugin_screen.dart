import 'package:flutter/material.dart';

import '../models/plugin_manifest.dart';
import '../services/plugin_repository.dart';
import '../services/plugin_validator.dart';

class AddPluginScreen extends StatefulWidget {
  const AddPluginScreen({super.key, required this.repository});

  final PluginRepository repository;

  @override
  State<AddPluginScreen> createState() => _AddPluginScreenState();
}

class _AddPluginScreenState extends State<AddPluginScreen> {
  PluginManifest? _preview;
  String? _error;
  bool _isBusy = false;

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
                      onPressed: _isBusy ? null : _showUrlComingSoon,
                      icon: const Icon(Icons.link_outlined),
                      label: const Text('Dán URL plugin'),
                    ),
                  ],
                ),
                if (_isBusy) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  const Center(child: Text('Đang kiểm tra plugin...')),
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
                    onCancel: () => setState(() => _preview = null),
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

  Future<void> _pickPluginFile() async {
    setState(() {
      _isBusy = true;
      _error = null;
      _preview = null;
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
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _installPreview() async {
    final plugin = _preview;
    if (plugin == null) return;
    setState(() => _isBusy = true);
    try {
      await widget.repository.installPlugin(plugin);
      if (!mounted) return;
      _showMessage('Đã cài plugin');
      Navigator.of(context).pop(true);
    } on PluginValidationException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showUrlComingSoon() {
    _showMessage('Thêm plugin bằng URL sẽ được hỗ trợ ở phiên bản sau.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PluginPreviewCard extends StatelessWidget {
  const _PluginPreviewCard({
    required this.plugin,
    required this.onCancel,
    required this.onInstall,
  });

  final PluginManifest plugin;
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
