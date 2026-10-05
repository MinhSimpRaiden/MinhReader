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
// A unified web-style layout container for the app
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


  }
