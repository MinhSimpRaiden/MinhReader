import 'package:flutter/material.dart';

import '../../../data/local/local_database.dart';
import '../../account/screens/account_sync_screen.dart';
import '../../library/providers/app_controller.dart';
import '../../sources/screens/sources_screen.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _backupService = BackupService();
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<ThemeMode>(
                  initialValue: settings.themeMode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Theo hệ thống'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Sáng'),
                    ),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Tối')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    controller.updateSettings(
                      settings.copyWith(themeMode: value),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'Cỡ chữ mặc định: ${settings.fontSize.toStringAsFixed(0)}',
                ),
                Slider(
                  min: 14,
                  max: 28,
                  divisions: 14,
                  value: settings.fontSize,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(fontSize: value),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Giãn dòng mặc định: ${settings.lineHeight.toStringAsFixed(2)}',
                ),
                Slider(
                  min: 1.2,
                  max: 2.2,
                  divisions: 10,
                  value: settings.lineHeight,
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(lineHeight: value),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: settings.fontFamily,
                  decoration: const InputDecoration(labelText: 'Font chữ'),
                  items: const [
                    DropdownMenuItem(value: 'Roboto', child: Text('Roboto')),
                    DropdownMenuItem(value: 'serif', child: Text('Serif')),
                    DropdownMenuItem(
                      value: 'monospace',
                      child: Text('Monospace'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    controller.updateSettings(
                      settings.copyWith(fontFamily: value),
                    );
                  },
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: controller.resetSettings,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset cài đặt đọc về mặc định'),
                ),
                const SizedBox(height: 28),
                _SettingsSectionTitle('Tài khoản & Đồng bộ'),
                const SizedBox(height: 8),
                const Text(
                  'Chỉ dùng offline. Cloud chưa được cấu hình và dữ liệu local vẫn được giữ trên thiết bị này.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _openAccountSync,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Tài khoản & Đồng bộ'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _openPluginManager,
                  icon: const Icon(Icons.extension_outlined),
                  label: const Text('Quản lý plugin nguồn truyện'),
                ),
                const SizedBox(height: 28),
                _SettingsSectionTitle('Sao lưu dữ liệu'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isBusy ? null : _exportBackup,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Xuất bản sao lưu'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _confirmAndImportBackup,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Nhập bản sao lưu'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isBusy ? null : _showLocalDataPath,
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('Xem vị trí dữ liệu local'),
                ),
                if (_isBusy) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAccountSync() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AccountSyncScreen()));
  }

  void _openPluginManager() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SourcesScreen()));
  }

  Future<void> _exportBackup() async {
    setState(() => _isBusy = true);
    try {
      final result = await _backupService.exportBackup();
      if (!mounted) return;
      _showMessage('Đã xuất bản sao lưu: ${result.path}');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể xuất bản sao lưu');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _confirmAndImportBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập bản sao lưu'),
        content: const Text(
          'Việc khôi phục sẽ thay thế dữ liệu hiện tại. Bạn nên xuất bản sao lưu trước khi tiếp tục.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tiếp tục khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      final result = await _backupService.pickAndRestoreBackup();
      if (!mounted || result == null) return;
      await AppScope.of(context).load();
      if (!mounted) return;
      _showMessage(
        'Đã khôi phục dữ liệu. Dữ liệu hiện tại đã được sao lưu tự động trước khi khôi phục: ${result.automaticBackupPath}',
      );
    } on BackupValidationException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể khôi phục dữ liệu');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showLocalDataPath() async {
    setState(() => _isBusy = true);
    try {
      final path = await _backupService.localDataPath();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Vị trí dữ liệu local'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Không thể xem vị trí dữ liệu local');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
