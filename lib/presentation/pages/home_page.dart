import 'package:flutter/material.dart';
import 'package:small_ssh/app/settings.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/domain/models/auth_method.dart';
import 'package:small_ssh/domain/models/connection_state_status.dart';
import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';
import 'package:small_ssh/presentation/widgets/host_form_dialog.dart';
import 'package:small_ssh/presentation/widgets/password_prompt_dialog.dart';
import 'package:small_ssh/presentation/widgets/terminal_panel.dart';
import 'package:small_ssh/presentation/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.orchestrator,
    required this.settings,
    required this.credentialRepository,
  });

  final SessionOrchestrator orchestrator;
  final AppSettings settings;
  final CredentialRepository credentialRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<void> _openHostDialog() async {
    final result = await showDialog<HostFormResult>(
      context: context,
      builder: (context) => const HostFormDialog(),
    );

    if (!mounted || result == null) {
      return;
    }

    final error = await widget.orchestrator.addHostProfile(
      name: result.name,
      host: result.host,
      port: result.port,
      username: result.username,
      password: result.password,
      privateKeyMode: result.privateKeyMode,
      privateKey: result.privateKey,
      privateKeyPassphrase: result.privateKeyPassphrase,
      authOrderMode: result.authOrderMode,
      authOrder: result.authOrder,
    );

    if (!mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _confirmDeleteHost(HostProfile host) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Host'),
          content: Text('Delete "${host.name}" from host list?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    await widget.orchestrator.removeHostProfile(host.id);
  }

  Future<void> _openEditHostDialog(HostProfile host) async {
    final result = await showDialog<HostFormResult>(
      context: context,
      builder: (context) => HostFormDialog(initialHost: host),
    );

    if (!mounted || result == null) {
      return;
    }

    final error = await widget.orchestrator.updateHostProfile(
      hostId: host.id,
      name: result.name,
      host: result.host,
      port: result.port,
      username: result.username,
      password: result.password,
      privateKeyMode: result.privateKeyMode,
      privateKey: result.privateKey,
      privateKeyPassphrase: result.privateKeyPassphrase,
      authOrderMode: result.authOrderMode,
      authOrder: result.authOrder,
    );

    if (!mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _connectToHost(HostProfile host) async {
    final authOrder = _resolveAuthOrder(host);
    final needsPassword = await widget.orchestrator.needsPasswordForHost(
      host.id,
      authOrder: authOrder,
    );
    String? override;
    if (needsPassword) {
      final entered = await showDialog<String>(
        context: context,
        builder: (context) => PasswordPromptDialog(host: host),
      );
      if (!mounted || entered == null || entered.trim().isEmpty) {
        return;
      }
      override = entered;
    }

    await widget.orchestrator.connectToHost(
      host.id,
      passwordOverride: override,
      authOrder: authOrder,
    );
  }

  List<AuthMethod> _resolveAuthOrder(HostProfile host) {
    return host.authOrderMode == AuthOrderMode.host
        ? host.authOrder
        : widget.settings.authOrder;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          settings: widget.settings,
          credentialRepository: widget.credentialRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.orchestrator, widget.settings]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('small_ssh'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 320,
                  child: Card(
                    child: _HostListPanel(
                      loading: widget.orchestrator.loadingHosts,
                      hosts: widget.orchestrator.hosts,
                      onConnect: _connectToHost,
                      onAddHost: _openHostDialog,
                      onEditHost: _openEditHostDialog,
                      onDeleteHost: _confirmDeleteHost,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: TerminalPanel(
                      sessions: widget.orchestrator.sessions,
                      activeSessionId: widget.orchestrator.activeSessionId,
                      onSelectSession: widget.orchestrator.setActiveSession,
                      onDeleteSession: widget.orchestrator.removeSession,
                      onSendInput: widget.orchestrator.sendInput,
                      onResizeTerminal: widget.orchestrator.resizeTerminal,
                      settings: widget.settings,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HostListPanel extends StatelessWidget {
  const _HostListPanel({
    required this.loading,
    required this.hosts,
    required this.onConnect,
    required this.onAddHost,
    required this.onEditHost,
    required this.onDeleteHost,
  });

  final bool loading;
  final List<HostProfile> hosts;
  final Future<void> Function(HostProfile host) onConnect;
  final Future<void> Function() onAddHost;
  final Future<void> Function(HostProfile host) onEditHost;
  final Future<void> Function(HostProfile host) onDeleteHost;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hosts', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddHost,
              icon: const Icon(Icons.add),
              label: const Text('Add Host'),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: hosts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final host = hosts[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          host.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('${host.username}@${host.host}:${host.port}'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => onConnect(host),
                                child: const Text('Connect'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => onEditHost(host),
                              tooltip: 'Edit host',
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => onDeleteHost(host),
                              tooltip: 'Delete host',
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Using dartssh2 backend. Host key trust flow will be added next.',
          ),
        ],
      ),
    );
  }
}

String statusLabel(ConnectionStateStatus status) {
  switch (status) {
    case ConnectionStateStatus.idle:
      return 'Idle';
    case ConnectionStateStatus.connecting:
      return 'Connecting';
    case ConnectionStateStatus.connected:
      return 'Connected';
    case ConnectionStateStatus.reconnecting:
      return 'Reconnecting';
    case ConnectionStateStatus.disconnected:
      return 'Disconnected';
    case ConnectionStateStatus.error:
      return 'Error';
  }
}
