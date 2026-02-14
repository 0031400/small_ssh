import 'package:flutter/material.dart';
import 'package:small_ssh/app/settings.dart';
import 'package:small_ssh/domain/models/credential_ref.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.settings,
    required this.credentialRepository,
  });

  final AppSettings settings;
  final CredentialRepository credentialRepository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _globalKeyController = TextEditingController();
  final TextEditingController _globalPassphraseController =
      TextEditingController();
  bool _loadingKey = true;
  bool _savingKey = false;

  @override
  void initState() {
    super.initState();
    _loadGlobalKey();
  }

  @override
  void dispose() {
    _globalKeyController.dispose();
    _globalPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalKey() async {
    final key = await widget.credentialRepository.readSecret(
      const CredentialRef(
        id: 'global-private-key',
        kind: CredentialKind.privateKeyText,
      ),
    );
    final passphrase = await widget.credentialRepository.readSecret(
      const CredentialRef(
        id: 'global-private-key-passphrase',
        kind: CredentialKind.privateKeyPassphrase,
      ),
    );

    _globalKeyController.text = key ?? '';
    _globalPassphraseController.text = passphrase ?? '';
    if (mounted) {
      setState(() => _loadingKey = false);
    }
  }

  Future<void> _saveGlobalKey() async {
    setState(() => _savingKey = true);
    await widget.credentialRepository.writeSecret(
      const CredentialRef(
        id: 'global-private-key',
        kind: CredentialKind.privateKeyText,
      ),
      _globalKeyController.text,
    );
    await widget.credentialRepository.writeSecret(
      const CredentialRef(
        id: 'global-private-key-passphrase',
        kind: CredentialKind.privateKeyPassphrase,
      ),
      _globalPassphraseController.text,
    );
    if (mounted) {
      setState(() => _savingKey = false);
    }
  }

  Future<void> _clearGlobalKey() async {
    _globalKeyController.clear();
    _globalPassphraseController.clear();
    await _saveGlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: widget.settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              Text('通用', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('主题'),
                  trailing: DropdownButton<ThemeMode>(
                    value: widget.settings.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        widget.settings.setThemeMode(value);
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
              const SizedBox(height: 10),
              Text('终端', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.terminal_outlined),
                          SizedBox(width: 8),
                          Text('字体大小'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: widget.settings.terminalFontSize,
                        min: 10,
                        max: 22,
                        divisions: 12,
                        label: widget.settings.terminalFontSize.toStringAsFixed(
                          0,
                        ),
                        onChanged: widget.settings.setTerminalFontSize,
                      ),
                      Text(
                        '当前：${widget.settings.terminalFontSize.toStringAsFixed(0)}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.folder_outlined),
                  title: const Text('SFTP 面板'),
                  dense: true,
                  value: widget.settings.autoOpenSftpPanel,
                  onChanged: widget.settings.setAutoOpenSftpPanel,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.content_copy_outlined),
                      title: Text('复制/粘贴'),
                    ),
                    RadioGroup<ClipboardBehavior>(
                      groupValue: widget.settings.clipboardBehavior,
                      onChanged: (value) {
                        if (value != null) {
                          widget.settings.setClipboardBehavior(value);
                        }
                      },
                      child: Column(
                        children: const [
                          RadioListTile<ClipboardBehavior>(
                            value: ClipboardBehavior.contextMenu,
                            title: Text('弹出菜单'),
                            subtitle: Text('右键显示复制/粘贴菜单'),
                          ),
                          RadioListTile<ClipboardBehavior>(
                            value: ClipboardBehavior.direct,
                            title: Text('直接复制/粘贴'),
                            subtitle: Text('有选中则复制，无选中则粘贴'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('全局私钥', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _globalKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Private Key',
                        ),
                        obscureText: true,
                        keyboardType: TextInputType.visiblePassword,
                        enableSuggestions: false,
                        autocorrect: false,
                        maxLines: 1,
                        enabled: !_loadingKey && !_savingKey,
                      ),
                      TextFormField(
                        controller: _globalPassphraseController,
                        decoration: const InputDecoration(
                          labelText: 'Passphrase (optional)',
                        ),
                        obscureText: true,
                        enabled: !_loadingKey && !_savingKey,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: _loadingKey || _savingKey
                                ? null
                                : _saveGlobalKey,
                            child: Text(_savingKey ? 'Saving...' : 'Save Key'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _loadingKey || _savingKey
                                ? null
                                : _clearGlobalKey,
                            child: const Text('Clear'),
                          ),
                          const SizedBox(width: 8),
                          if (!_loadingKey)
                            Text(
                              _globalKeyController.text.trim().isEmpty
                                  ? '未设置'
                                  : '已保存',
                              style: textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('关于', style: textTheme.titleMedium),
              const SizedBox(height: 6),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('small_ssh'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
