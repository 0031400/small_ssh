import 'package:flutter/material.dart';
import 'package:small_ssh/domain/models/host_profile.dart';

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
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final PrivateKeyMode privateKeyMode;
  final String privateKey;
  final String privateKeyPassphrase;
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
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Host' : 'Add Host'),
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Update' : 'Save'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final connectionFields = <Widget>[
                Text(
                  'Connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: 'Host'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(labelText: 'Port'),
                        keyboardType: TextInputType.number,
                        validator: _validatePort,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password (optional, leave blank to keep)',
                  ),
                  obscureText: true,
                ),
              ];

              final authFields = <Widget>[
                Text(
                  'Authentication',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PrivateKeyMode>(
                  initialValue: _privateKeyMode,
                  decoration: const InputDecoration(labelText: 'Private Key'),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _privateKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Private Key (optional, leave blank to keep)',
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.visiblePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _privateKeyPassphraseController,
                    decoration: const InputDecoration(
                      labelText:
                          'Private Key Passphrase (optional, leave blank to keep)',
                    ),
                    obscureText: true,
                  ),
                ],
              ];

              return Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: connectionFields,
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: authFields,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...connectionFields,
                              const SizedBox(height: 24),
                              ...authFields,
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
      ),
    );
  }
}
