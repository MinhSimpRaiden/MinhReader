import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repositories/library_repository.dart';
import 'features/library/providers/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AppScope(
      controller: AppController(LibraryRepository()),
      child: const MinhReaderApp(),
    ),
  );
}
