import 'package:flutter/material.dart';

class HostFormResult {
  const HostFormResult({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
}

class HostFormDialog extends StatefulWidget {
  const HostFormDialog({super.key});

  @override
  State<HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends State<HostFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController(
    text: '22',
  );
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Host'),
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
                  labelText: 'Password (optional)',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
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
      ),
    );
  }
}
