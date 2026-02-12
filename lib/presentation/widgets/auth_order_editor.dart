import 'package:flutter/material.dart';
import 'package:small_ssh/domain/models/auth_method.dart';

class AuthOrderEditor extends StatelessWidget {
  const AuthOrderEditor({
    super.key,
    required this.order,
    required this.onChanged,
    this.height = 160,
  });

  final List<AuthMethod> order;
  final ValueChanged<List<AuthMethod>> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ReorderableListView.builder(
        itemCount: order.length,
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final next = List<AuthMethod>.of(order);
          final item = next.removeAt(oldIndex);
          next.insert(newIndex, item);
          onChanged(next);
        },
        itemBuilder: (context, index) {
          final method = order[index];
          return ListTile(
            key: ValueKey(method.name),
            leading: const Icon(Icons.drag_handle),
            title: Text(authMethodLabel(method)),
            subtitle: Text(_methodDescription(method)),
          );
        },
      ),
    );
  }

  String _methodDescription(AuthMethod method) {
    switch (method) {
      case AuthMethod.password:
        return 'Password authentication';
      case AuthMethod.privateKey:
        return 'Public key authentication';
      case AuthMethod.keyboardInteractive:
        return 'Keyboard-interactive authentication';
    }
  }
}
