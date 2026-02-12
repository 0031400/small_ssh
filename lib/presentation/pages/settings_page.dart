import 'package:flutter/material.dart';
import 'package:small_ssh/app/settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('设置'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('通用', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('主题'),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        settings.setThemeMode(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('跟随系统'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('浅色'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('深色'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('终端', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.terminal_outlined),
                          SizedBox(width: 12),
                          Text('字体大小'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: settings.terminalFontSize,
                        min: 10,
                        max: 22,
                        divisions: 12,
                        label: settings.terminalFontSize.toStringAsFixed(0),
                        onChanged: settings.setTerminalFontSize,
                      ),
                      Text(
                        '当前：${settings.terminalFontSize.toStringAsFixed(0)}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.content_copy_outlined),
                      title: Text('复制/粘贴'),
                      subtitle: Text('右键行为'),
                    ),
                    RadioListTile<ClipboardBehavior>(
                      value: ClipboardBehavior.contextMenu,
                      groupValue: settings.clipboardBehavior,
                      onChanged: (value) {
                        if (value != null) {
                          settings.setClipboardBehavior(value);
                        }
                      },
                      title: const Text('弹出菜单'),
                      subtitle: const Text('右键显示复制/粘贴菜单'),
                    ),
                    RadioListTile<ClipboardBehavior>(
                      value: ClipboardBehavior.direct,
                      groupValue: settings.clipboardBehavior,
                      onChanged: (value) {
                        if (value != null) {
                          settings.setClipboardBehavior(value);
                        }
                      },
                      title: const Text('直接复制/粘贴'),
                      subtitle: const Text('有选中则复制，无选中则粘贴'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('关于', style: textTheme.titleMedium),
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
      },
    );
  }
}
