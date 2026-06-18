import 'package:flutter/material.dart';

import '../../sync/controllers/sync_controller.dart';
import '../../sync/models/sync_status.dart';
import '../../sync/services/local_only_sync_service.dart';
import '../controllers/auth_controller.dart';
import '../models/auth_state.dart';
import '../services/auth_service.dart';
import '../services/disabled_cloud_auth_service.dart';

class AccountSyncScreen extends StatefulWidget {
  const AccountSyncScreen({super.key});

  @override
  State<AccountSyncScreen> createState() => _AccountSyncScreenState();
}

class _AccountSyncScreenState extends State<AccountSyncScreen> {
  late final AuthController _authController;
  late final SyncController _syncController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authController = AuthController(DisabledCloudAuthService())..load();
    _syncController = SyncController(LocalOnlySyncService())..load();
  }

  @override
  void dispose() {
    _authController.dispose();
    _syncController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản & Đồng bộ')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListenableBuilder(
              listenable: Listenable.merge([_authController, _syncController]),
              builder: (context, _) {
                final auth = _authController.state;
                final sync = _syncController.status;
                final busy = _authController.isBusy || _syncController.isBusy;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatusCard(auth: auth, sync: sync),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: busy ? null : _signIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Đăng nhập'),
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _register,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Đăng ký'),
                        ),
                        TextButton.icon(
                          onPressed: busy ? null : _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng xuất'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Đồng bộ',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Dữ liệu local vẫn được giữ trên thiết bị này. App vẫn dùng được 100% khi chưa đăng nhập.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: busy ? null : _enableSync,
                          icon: const Icon(Icons.sync_outlined),
                          label: const Text('Bật đồng bộ'),
                        ),
                        FilledButton.icon(
                          onPressed: busy ? null : _syncNow,
                          icon: const Icon(Icons.cloud_sync_outlined),
                          label: const Text('Đồng bộ ngay'),
                        ),
                      ],
                    ),
                    if (busy) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    try {
      await _authController.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _register() async {
    try {
      await _authController.register(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _signOut() async {
    await _authController.signOut();
    _showMessage('Dữ liệu local vẫn được giữ trên thiết bị này');
  }

  Future<void> _enableSync() async {
    await _syncController.enableSync();
    _authController.markCloudNotConfigured();
    _showMessage('Cloud chưa được cấu hình');
  }

  Future<void> _syncNow() async {
    await _syncController.syncNow();
    _showMessage('Cloud chưa được cấu hình. Chỉ dùng offline.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.auth, required this.sync});

  final AuthState auth;
  final SyncStatus sync;

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
              'Tài khoản & Đồng bộ',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _StatusRow(label: 'Tài khoản', value: _authLabel(auth)),
            _StatusRow(label: 'Chế độ', value: _syncLabel(sync)),
            _StatusRow(
              label: 'Lần đồng bộ gần nhất',
              value: sync.lastSyncTime?.toLocal().toString() ?? 'Chưa có',
            ),
            const SizedBox(height: 8),
            const Text('Cloud chưa được cấu hình'),
            const Text('Dữ liệu local vẫn được giữ trên thiết bị này'),
          ],
        ),
      ),
    );
  }

  String _authLabel(AuthState state) {
    return switch (state.status) {
      AuthStatus.signedIn => 'Đã đăng nhập',
      AuthStatus.signedOut => 'Chưa đăng nhập',
      AuthStatus.localOnly => 'Chỉ dùng offline',
      AuthStatus.cloudNotConfigured => 'Cloud chưa được cấu hình',
    };
  }

  String _syncLabel(SyncStatus status) {
    return switch (status.phase) {
      SyncPhase.disabled => 'Chưa đăng nhập',
      SyncPhase.localOnly => 'Chỉ dùng offline',
      SyncPhase.cloudNotConfigured => 'Cloud chưa được cấu hình',
      SyncPhase.syncing => 'Đang đồng bộ',
      SyncPhase.success => 'Đã đăng nhập',
      SyncPhase.failed => 'Cloud chưa được cấu hình',
    };
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
