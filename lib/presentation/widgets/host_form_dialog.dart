import 'package:flutter/material.dart';
import 'package:small_ssh/domain/models/auth_method.dart';
import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/presentation/widgets/auth_order_editor.dart';

class HostFormResult {
  const HostFormResult({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.privateKeyMode,
    required this.privateKey,
    required this.privateKeyPassphrase,
    required this.authOrderMode,
    required this.authOrder,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final PrivateKeyMode privateKeyMode;
  final String privateKey;
  final String privateKeyPassphrase;
  final AuthOrderMode authOrderMode;
  final List<AuthMethod> authOrder;
}

class HostFormDialog extends StatefulWidget {
  const HostFormDialog({super.key, this.initialHost});

  final HostProfile? initialHost;

  @override
  State<HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends State<HostFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;
  late final TextEditingController _privateKeyPassphraseController;
  late PrivateKeyMode _privateKeyMode;
  late AuthOrderMode _authOrderMode;
  late List<AuthMethod> _authOrder;

  bool get _isEditing => widget.initialHost != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialHost;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _hostController = TextEditingController(text: initial?.host ?? '');
    _portController = TextEditingController(text: '${initial?.port ?? 22}');
    _usernameController = TextEditingController(text: initial?.username ?? '');
    _passwordController = TextEditingController();
    _privateKeyController = TextEditingController();
    _privateKeyPassphraseController = TextEditingController();
    _privateKeyMode = initial?.privateKeyMode ?? PrivateKeyMode.global;
    _authOrderMode = initial?.authOrderMode ?? AuthOrderMode.global;
    _authOrder = List<AuthMethod>.of(
      initial?.authOrder ?? defaultAuthOrder,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _privateKeyPassphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Host' : 'Add Host'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(labelText: 'Host'),
                validator: _required,
              ),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                validator: _validatePort,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: _required,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password (optional, leave blank to keep)',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PrivateKeyMode>(
                value: _privateKeyMode,
                decoration: const InputDecoration(
                  labelText: 'Private Key',
                ),
                items: const [
                  DropdownMenuItem(
                    value: PrivateKeyMode.global,
                    child: Text('Use global private key'),
                  ),
                  DropdownMenuItem(
                    value: PrivateKeyMode.host,
                    child: Text('Use host-specific private key'),
                  ),
                  DropdownMenuItem(
                    value: PrivateKeyMode.none,
                    child: Text('Do not use private key'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _privateKeyMode = value);
                },
              ),
              if (_privateKeyMode == PrivateKeyMode.host) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _privateKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Private Key (optional, leave blank to keep)',
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
                TextFormField(
                  controller: _privateKeyPassphraseController,
                  decoration: const InputDecoration(
                    labelText:
                        'Private Key Passphrase (optional, leave blank to keep)',
                  ),
                  obscureText: true,
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<AuthOrderMode>(
                value: _authOrderMode,
                decoration: const InputDecoration(
                  labelText: 'Auth Order',
                ),
                items: const [
                  DropdownMenuItem(
                    value: AuthOrderMode.global,
                    child: Text('Use global auth order'),
                  ),
                  DropdownMenuItem(
                    value: AuthOrderMode.host,
                    child: Text('Use host-specific auth order'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _authOrderMode = value);
                },
              ),
              if (_authOrderMode == AuthOrderMode.host) ...[
                const SizedBox(height: 8),
                AuthOrderEditor(
                  order: _authOrder,
                  onChanged: (next) => setState(() => _authOrder = next),
                  height: 180,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _validatePort(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) {
      return requiredError;
    }

    final parsed = int.tryParse(value!.trim());
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return '1-65535';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      HostFormResult(
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        port: int.parse(_portController.text.trim()),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        privateKeyMode: _privateKeyMode,
        privateKey: _privateKeyController.text,
        privateKeyPassphrase: _privateKeyPassphraseController.text,
        authOrderMode: _authOrderMode,
        authOrder: _authOrder,
      ),
    );
  }
}
