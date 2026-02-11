import 'package:flutter/material.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/domain/models/connection_state_status.dart';
import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/presentation/widgets/host_form_dialog.dart';
import 'package:small_ssh/presentation/widgets/terminal_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.orchestrator});

  final SessionOrchestrator orchestrator;

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
    );

    if (!mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.orchestrator,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('small_ssh')),
          body: Row(
            children: [
              SizedBox(
                width: 320,
                child: _HostListPanel(
                  loading: widget.orchestrator.loadingHosts,
                  hosts: widget.orchestrator.hosts,
                  onConnect: widget.orchestrator.connectToHost,
                  onAddHost: _openHostDialog,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: TerminalPanel(
                  sessions: widget.orchestrator.sessions,
                  activeSessionId: widget.orchestrator.activeSessionId,
                  onSelectSession: widget.orchestrator.setActiveSession,
                  onDisconnectSession: widget.orchestrator.disconnectSession,
                  onSendInput: widget.orchestrator.sendInput,
                ),
              ),
            ],
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
  });

  final bool loading;
  final List<HostProfile> hosts;
  final Future<void> Function(String hostId) onConnect;
  final Future<void> Function() onAddHost;

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
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => onConnect(host.id),
                            child: const Text('Connect'),
                          ),
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
