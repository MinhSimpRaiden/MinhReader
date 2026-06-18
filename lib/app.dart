import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/library/providers/app_controller.dart';
import 'features/library/screens/library_screen.dart';

class MinhReaderApp extends StatelessWidget {
  const MinhReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);
    final settings = controller.settings;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MinhReader',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.materialThemeMode,
      home: const LibraryScreen(),
    );
  }
}
