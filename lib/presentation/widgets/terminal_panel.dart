import 'package:flutter/material.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/presentation/pages/home_page.dart';

class TerminalPanel extends StatefulWidget {
  const TerminalPanel({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onDisconnectSession,
    required this.onSendInput,
  });

  final List<SessionView> sessions;
  final String? activeSessionId;
  final Future<void> Function(String sessionId) onDisconnectSession;
  final Future<void> Function(String sessionId, String input) onSendInput;
  final void Function(String sessionId) onSelectSession;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      return const Center(
        child: Text('No active session. Choose a host and connect.'),
      );
    }

    final active = widget.sessions.firstWhere(
      (session) => session.session.id == widget.activeSessionId,
      orElse: () => widget.sessions.first,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.sessions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final session = widget.sessions[index];
                final selected = session.session.id == active.session.id;
                return ChoiceChip(
                  selected: selected,
                  label: Text(
                    '${session.hostProfile.name} (${statusLabel(session.session.status)})',
                  ),
                  onSelected: (_) => widget.onSelectSession(session.session.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                itemCount: active.output.length,
                itemBuilder: (context, index) {
                  return Text(
                    active.output[index],
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontFamily: 'Consolas',
                      fontSize: 13,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Type command and press Enter',
                  ),
                  onSubmitted: (_) => _submit(active.session.id),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _submit(active.session.id),
                child: const Text('Send'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => widget.onDisconnectSession(active.session.id),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit(String sessionId) async {
    final input = _inputController.text;
    if (input.trim().isEmpty) {
      return;
    }

    _inputController.clear();
    await widget.onSendInput(sessionId, input);
  }
}
