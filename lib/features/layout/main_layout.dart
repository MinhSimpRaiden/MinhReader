import 'package:flutter/material.dart';
import '../library/screens/library_screen.dart';
import '../sources/screens/sources_screen.dart';
import '../settings/screens/settings_screen.dart';
import '../plugins/screens/plugin_search_screen.dart';
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}
class _MainLayoutState extends State<MainLayout> {
    int _selectedIndex = 0;
  final _screens = const [
    LibraryScreen(),
    PluginSearchScreen(),
    SourcesScreen(),
    SettingsScreen(),
  ];

}
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    return Scaffold();
  }
