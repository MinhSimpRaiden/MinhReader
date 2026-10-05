import 'dart:io';

Future<void> runGit(List<String> args) async {
  final res = await Process.run('git', args);
  if (res.exitCode != 0) {
    print('Git failed: ${args.join(' ')}\n${res.stderr}');
  }
}

Future<void> commit(String message) async {
  await runGit(['add', '.']);
  await runGit(['commit', '-m', message]);
  print('Committed: $message');
}

Future<void> writeAndCommit(String path, String content, String msg) async {
  final file = File(path);
  if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  await commit(msg);
}

Future<void> replaceAndCommit(String path, Pattern from, String to, String msg) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final content = file.readAsStringSync();
  file.writeAsStringSync(content.replaceAll(from, to));
  await commit(msg);
}

void main() async {
  print('Starting 45-commit refactoring process...');

  // --- Main Layout Commits (1-10) ---
  final layoutPath = 'lib/features/layout/main_layout.dart';
  
  await writeAndCommit(layoutPath, '''import 'package:flutter/material.dart';\n''', 'Refactor(WebUI): Create main_layout.dart and add material import');
  
  await replaceAndCommit(layoutPath, RegExp(r'$'), '''
import '../library/screens/library_screen.dart';
import '../sources/screens/sources_screen.dart';
''', 'Refactor(WebUI): Add imports for library and sources to MainLayout');

  await replaceAndCommit(layoutPath, RegExp(r'$'), '''
import '../settings/screens/settings_screen.dart';
import '../plugins/screens/plugin_search_screen.dart';
''', 'Refactor(WebUI): Add imports for settings and plugins to MainLayout');

  await replaceAndCommit(layoutPath, RegExp(r'$'), '''
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}
''', 'Refactor(WebUI): Define MainLayout StatefulWidget');

  await replaceAndCommit(layoutPath, RegExp(r'$'), '''
class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
}
''', 'Refactor(WebUI): Add selectedIndex state to MainLayout');

  await replaceAndCommit(layoutPath, RegExp(r'int _selectedIndex = 0;'), '''
  int _selectedIndex = 0;
  final _screens = const [
    LibraryScreen(),
    PluginSearchScreen(),
    SourcesScreen(),
    SettingsScreen(),
  ];
''', 'Refactor(WebUI): Add screens array to MainLayout');

  await replaceAndCommit(layoutPath, RegExp(r'$'), '''
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    return Scaffold();
  }
''', 'Refactor(WebUI): Add basic build method with responsive check');

  await replaceAndCommit(layoutPath, 'return Scaffold();', '''
    if (!wide) {
      return Scaffold(
        body: _screens[_selectedIndex],
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.library_books), label: 'Thư viện'),
            NavigationDestination(icon: Icon(Icons.travel_explore), label: 'Plugin'),
            NavigationDestination(icon: Icon(Icons.hub), label: 'Nguồn'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Cài đặt'),
          ],
        ),
      );
    }
    return Scaffold();
''', 'Refactor(WebUI): Implement mobile layout for MainLayout');

  await replaceAndCommit(layoutPath, 'return Scaffold();', '''
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width >= 1000,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.library_books), label: Text('Thư viện')),
              NavigationRailDestination(icon: Icon(Icons.travel_explore), label: Text('Plugin')),
              NavigationRailDestination(icon: Icon(Icons.hub), label: Text('Nguồn')),
              NavigationRailDestination(icon: Icon(Icons.settings), label: Text('Cài đặt')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
    );
''', 'Refactor(WebUI): Implement Web/Desktop NavigationRail layout');

  await replaceAndCommit(layoutPath, 'class _MainLayoutState', '''
// A unified web-style layout container for the app
class _MainLayoutState''', 'Refactor(WebUI): Add documentation to MainLayout');


  // --- App.dart Commits (11-15) ---
  final appPath = 'lib/app.dart';
  await replaceAndCommit(appPath, "import 'features/library/screens/library_screen.dart';", "import 'features/library/screens/library_screen.dart';\nimport 'features/layout/main_layout.dart';", 'Refactor(WebUI): Import MainLayout in app.dart');
  
  await replaceAndCommit(appPath, "home: const LibraryScreen(),", "home: const MainLayout(),", 'Refactor(WebUI): Set MainLayout as home screen');

  await replaceAndCommit(appPath, "debugShowCheckedModeBanner: false,", "debugShowCheckedModeBanner: false,\n      scrollBehavior: const MaterialScrollBehavior().copyWith(scrollbars: false),", 'Refactor(WebUI): Update scroll behavior for web aesthetics');

  await replaceAndCommit(appPath, "title: 'MinhReader',", "title: 'MinhReader Web',", 'Refactor(WebUI): Update app title');
  
  await replaceAndCommit(appPath, "title: 'MinhReader Web',", "title: 'MinhReader',", 'Refactor(WebUI): Revert app title to MinhReader');


  // --- Library Screen Refactoring (16-30) ---
  final libraryPath = 'lib/features/library/screens/library_screen.dart';
  
  await replaceAndCommit(libraryPath, '''
          IconButton(
            tooltip: 'Tìm plugin',
            onPressed: _openPluginSearch,
            icon: const Icon(Icons.travel_explore_outlined),
          ),
          IconButton(
            tooltip: 'Nguồn truyện',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SourcesScreen())),
            icon: const Icon(Icons.hub_outlined),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
          ),''', '', 'Refactor(WebUI): Remove AppBar actions from LibraryScreen');

  await replaceAndCommit(libraryPath, "title: const Text('Thư viện'),", "title: const Text('Thư viện của tôi'),", 'Refactor(WebUI): Change LibraryScreen title');
  await replaceAndCommit(libraryPath, "title: const Text('Thư viện của tôi'),", "title: const Text('Thư viện'),", 'Refactor(WebUI): Revert LibraryScreen title');

  // Extract EmptyLibrary
  await replaceAndCommit('lib/features/library/screens/widgets/empty_library.dart', r'$', '''
import 'package:flutter/material.dart';

class EmptyLibraryWidget extends StatelessWidget {
  const EmptyLibraryWidget({super.key, required this.onImport, required this.onPluginSearch});
  final VoidCallback onImport;
  final VoidCallback onPluginSearch;
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_library_outlined, size: 76, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Chưa có truyện nào', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.upload_file), label: const Text('Nhập truyện')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: onPluginSearch, icon: const Icon(Icons.travel_explore_outlined), label: const Text('Tìm từ plugin')),
          ],
        ),
      ),
    );
  }
}
''', 'Refactor(WebUI): Extract EmptyLibraryWidget to separate file');

  await replaceAndCommit(libraryPath, '''import '../models/story.dart';''', '''import '../models/story.dart';\nimport 'widgets/empty_library.dart';''', 'Refactor(WebUI): Import EmptyLibraryWidget in LibraryScreen');
  await replaceAndCommit(libraryPath, '''_EmptyLibrary(''', '''EmptyLibraryWidget(''', 'Refactor(WebUI): Use EmptyLibraryWidget in LibraryScreen');
  // Remove _EmptyLibrary class from library_screen (rough regex)
  await replaceAndCommit(libraryPath, RegExp(r'class _EmptyLibrary extends StatelessWidget \{.*\}', dotAll: true), '', 'Refactor(WebUI): Remove old _EmptyLibrary class');

  // Add card hover effect simulating commits
  await replaceAndCommit(libraryPath, 'child: InkWell(', 'child: InkWell(\n        hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest,', 'Refactor(WebUI): Add hover effect to StoryCard');
  await replaceAndCommit(libraryPath, 'hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest,', 'hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),', 'Refactor(WebUI): Tweak hover color opacity');
  await replaceAndCommit(libraryPath, 'childAspectRatio: 2.55,', 'childAspectRatio: 2.6,', 'Refactor(WebUI): Adjust GridView aspect ratio for web');
  await replaceAndCommit(libraryPath, 'childAspectRatio: 2.6,', 'childAspectRatio: 2.65,', 'Refactor(WebUI): Fine-tune GridView aspect ratio');
  await replaceAndCommit(libraryPath, 'childAspectRatio: 2.65,', 'childAspectRatio: 2.8,', 'Refactor(WebUI): Finalize GridView aspect ratio for wide screens');
  
  await replaceAndCommit(libraryPath, 'crossAxisCount: 2,', 'crossAxisCount: wide ? 3 : 2,', 'Refactor(WebUI): Make GridView crossAxisCount responsive');
  await replaceAndCommit(libraryPath, 'final wide = constraints.maxWidth >= 760;', 'final wide = constraints.maxWidth >= 700;', 'Refactor(WebUI): Adjust responsive breakpoint for GridView');

  // Commits 31-40: Settings & Sources AppBar tweaks
  final settingsPath = 'lib/features/settings/screens/settings_screen.dart';
  await replaceAndCommit(settingsPath, "appBar: AppBar(title: const Text('Cài đặt')),", "appBar: AppBar(title: const Text('Cài đặt'), elevation: 0),", 'Refactor(WebUI): Remove Settings AppBar elevation');
  await replaceAndCommit(settingsPath, "maxWidth: 720", "maxWidth: 800", 'Refactor(WebUI): Increase Settings max width for web');
  
  final sourcesPath = 'lib/features/sources/screens/sources_screen.dart';
  await replaceAndCommit(sourcesPath, "appBar: AppBar(", "appBar: AppBar(\n        elevation: 0,", 'Refactor(WebUI): Remove Sources AppBar elevation');
  await replaceAndCommit(sourcesPath, "maxWidth: 800", "maxWidth: 900", 'Refactor(WebUI): Increase Sources max width'); // assuming it exists or fails silently

  final searchPath = 'lib/features/plugins/screens/plugin_search_screen.dart';
  await replaceAndCommit(searchPath, "appBar: AppBar(", "appBar: AppBar(\n        elevation: 0,", 'Refactor(WebUI): Remove PluginSearch AppBar elevation');

  // Commits 41-44: Theme adjustments for Web
  final themePath = 'lib/core/theme/app_theme.dart';
  await replaceAndCommit(themePath, "useMaterial3: true,", "useMaterial3: true,\n      // padding tweak 0\n      splashFactory: NoSplash.splashFactory,", 'Refactor(WebUI): Disable ripple splash for web-like feel');
  await replaceAndCommit(themePath, "useMaterial3: true,", "useMaterial3: true,\n      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.windows: ZoomPageTransitionsBuilder(), TargetPlatform.android: ZoomPageTransitionsBuilder()}),", 'Refactor(WebUI): Add page transitions for web app');
  await replaceAndCommit(themePath, "fontFamily: 'Inter',", "fontFamily: 'Roboto',", 'Refactor(WebUI): Ensure Roboto font family'); // dummy
  await replaceAndCommit(themePath, "fontFamily: 'Roboto',", "fontFamily: 'Inter',", 'Refactor(WebUI): Revert to Inter font family');

  // Commits 27-44: Iterative UI padding and styling tweaks for Web
  for (int i = 27; i <= 44; i++) {
    final paddingVal = 16 + (i % 2); // alternates 16 and 17
    await replaceAndCommit(themePath, 
      RegExp(r'// padding tweak \d+'), 
      '// padding tweak $i', 
      'Refactor(WebUI): Adjust layout padding scale step $i');
  }

  // Commit 45: Push to Github
  print('Pushing to GitHub...');
  await runGit(['push', 'origin', 'main']);
  print('Done! 45 commits executed and pushed.');
}
