import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('General', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Theme'),
              subtitle: Text('Use system theme'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Terminal', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.terminal_outlined),
              title: Text('Font size'),
              subtitle: Text('Follow system defaults'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.content_copy_outlined),
              title: Text('Clipboard'),
              subtitle: Text('Right click to copy/paste'),
            ),
          ),
          const SizedBox(height: 16),
          Text('About', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('small_ssh'),
              subtitle: Text('Lightweight SSH client'),
            ),
          ),
        ],
      ),
    );
  }
}
