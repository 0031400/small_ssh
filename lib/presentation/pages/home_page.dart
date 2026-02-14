import 'package:flutter/material.dart';
import 'package:small_ssh/app/settings.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/domain/models/credential_ref.dart';
import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';
import 'package:small_ssh/infrastructure/ssh/ssh_gateway.dart';
import 'package:small_ssh/presentation/widgets/host_form_dialog.dart';
import 'package:small_ssh/presentation/widgets/password_prompt_dialog.dart';
import 'package:small_ssh/presentation/widgets/sftp_panel.dart';
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
  bool _sftpAvailable = true;
  bool _sftpPanelOpen = true;
  String? _lastSessionId;
  bool? _lastAutoOpen;

  @override
  void initState() {
    super.initState();
    _sftpPanelOpen = widget.settings.autoOpenSftpPanel;
    _lastAutoOpen = widget.settings.autoOpenSftpPanel;
  }

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
    final initialPassword = await widget.credentialRepository.readSecret(
      CredentialRef(id: '${host.id}-password', kind: CredentialKind.password),
    );
    if (!mounted) {
      return;
    }
    final result = await showDialog<HostFormResult>(
      context: context,
      builder: (context) =>
          HostFormDialog(initialHost: host, initialPassword: initialPassword),
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
    );

    if (!mounted || error == null) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _connectToHost(HostProfile host) async {
    final needsPassword = await widget.orchestrator.needsPasswordForHost(
      host.id,
    );
    if (!mounted) {
      return;
    }
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
      onKeyboardInteractive: _promptKeyboardInteractive,
    );
  }

  Future<List<String>?> _promptKeyboardInteractive(
    KeyboardInteractiveRequest request,
  ) async {
    if (!mounted) {
      return null;
    }
    final hasName = request.name.trim().isNotEmpty;
    final hasInstruction = request.instruction.trim().isNotEmpty;
    final hasPromptText = request.prompts.any(
      (item) => item.promptText.trim().isNotEmpty,
    );
    if (!hasName && !hasInstruction && !hasPromptText) {
      return [];
    }
    final controllers = List<TextEditingController>.generate(
      request.prompts.length,
      (_) => TextEditingController(),
      growable: false,
    );
    try {
      return await showDialog<List<String>>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              request.name.trim().isEmpty
                  ? 'Interactive Verification'
                  : request.name,
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.instruction.trim().isEmpty
                          ? 'Please complete interactive verification.'
                          : request.instruction,
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < request.prompts.length; i += 1) ...[
                      Text(
                        request.prompts[i].promptText.trim().isEmpty
                            ? 'Prompt ${i + 1}'
                            : request.prompts[i].promptText,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: controllers[i],
                        obscureText: !request.prompts[i].echo,
                      ),
                      if (i < request.prompts.length - 1)
                        const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  controllers.map((item) => item.text).toList(growable: false),
                ),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    } finally {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
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
        final currentSessionId = widget.orchestrator.activeSessionId;
        if (currentSessionId != _lastSessionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _lastSessionId = currentSessionId;
            setState(() => _sftpAvailable = true);
          });
        }
        final autoOpenSetting = widget.settings.autoOpenSftpPanel;
        if (_lastAutoOpen != autoOpenSetting) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _lastAutoOpen = autoOpenSetting;
            if (!autoOpenSetting) {
              setState(() => _sftpPanelOpen = false);
            } else {
              setState(() => _sftpPanelOpen = true);
            }
          });
        }
        final showSftpPanel = _sftpPanelOpen && _sftpAvailable;
        return Scaffold(
          appBar: AppBar(
            title: const Text('small_ssh'),
            actions: [
              IconButton(
                tooltip: showSftpPanel ? 'Hide SFTP' : 'Show SFTP',
                onPressed: () {
                  setState(() {
                    if (!_sftpAvailable) {
                      _sftpAvailable = true;
                    }
                    _sftpPanelOpen = !showSftpPanel;
                  });
                },
                icon: Icon(
                  showSftpPanel
                      ? Icons.folder_open_outlined
                      : Icons.folder_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 280,
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
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: TerminalPanel(
                            sessions: widget.orchestrator.sessions,
                            activeSessionId:
                                widget.orchestrator.activeSessionId,
                            onSelectSession:
                                widget.orchestrator.setActiveSession,
                            onDeleteSession: widget.orchestrator.removeSession,
                            onSendInput: widget.orchestrator.sendInput,
                            onResizeTerminal:
                                widget.orchestrator.resizeTerminal,
                            settings: widget.settings,
                          ),
                        ),
                      ),
                      if (showSftpPanel) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 250,
                          child: Card(
                            child: SftpPanel(
                              orchestrator: widget.orchestrator,
                              activeSessionId:
                                  widget.orchestrator.activeSessionId,
                              onAvailabilityChanged: (available) {
                                if (available == _sftpAvailable) {
                                  return;
                                }
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!mounted || available == _sftpAvailable) {
                                    return;
                                  }
                                  setState(() => _sftpAvailable = available);
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
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
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hosts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Add Host',
                visualDensity: VisualDensity.compact,
                onPressed: onAddHost,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              itemCount: hosts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final host = hosts[index];
                return Card(
                  child: ListTile(
                    dense: true,
                    minLeadingWidth: 0,
                    title: Text(
                      host.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Wrap(
                      spacing: 0,
                      children: [
                        IconButton(
                          tooltip: 'Connect',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onConnect(host),
                          icon: const Icon(Icons.link_outlined),
                        ),
                        IconButton(
                          onPressed: () => onEditHost(host),
                          tooltip: 'Edit host',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => onDeleteHost(host),
                          tooltip: 'Delete host',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
