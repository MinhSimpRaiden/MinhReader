import 'package:flutter/material.dart';

class PluginOnlineReaderScreen extends StatelessWidget {
  const PluginOnlineReaderScreen({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFFF4F1E8);
    const foreground = Color(0xFF202020);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: background,
        foregroundColor: foreground,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 20),
                SelectableText(
                  content,
                  style: const TextStyle(
                    color: foreground,
                    fontSize: 18,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
