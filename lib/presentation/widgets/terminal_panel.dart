import 'package:flutter/material.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/presentation/pages/home_page.dart';
import 'package:xterm/xterm.dart';

class TerminalPanel extends StatefulWidget {
  const TerminalPanel({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onDeleteSession,
    required this.onSendInput,
  });

  final List<SessionView> sessions;
  final String? activeSessionId;
  final Future<void> Function(String sessionId) onDeleteSession;
  final Future<void> Function(String sessionId, String input) onSendInput;
  final void Function(String sessionId) onSelectSession;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final Map<String, Terminal> _terminals = <String, Terminal>{};
  final Map<String, int> _renderedLineCount = <String, int>{};
  final Map<String, StringBuffer> _pendingInput = <String, StringBuffer>{};

  @override
  void dispose() {
    _terminals.clear();
    _renderedLineCount.clear();
    _pendingInput.clear();
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
    _syncTerminals(widget.sessions);
    final terminal = _terminals[active.session.id]!;

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
                return InputChip(
                  selected: selected,
                  label: Text(
                    '${session.hostProfile.name} (${statusLabel(session.session.status)})',
                  ),
                  onSelected: (_) => widget.onSelectSession(session.session.id),
                  onDeleted: () => widget.onDeleteSession(session.session.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: TerminalView(
                  hardwareKeyboardOnly:true,
                  terminal,
                  theme: const TerminalTheme(
                    cursor: Color(0xFFE2E8F0),
                    selection: Color(0x335B9CFF),
                    foreground: Color(0xFFE2E8F0),
                    background: Color(0xFF0B1220),
                    black: Color(0xFF111827),
                    red: Color(0xFFF87171),
                    green: Color(0xFF4ADE80),
                    yellow: Color(0xFFFACC15),
                    blue: Color(0xFF60A5FA),
                    magenta: Color(0xFFF472B6),
                    cyan: Color(0xFF22D3EE),
                    white: Color(0xFFE5E7EB),
                    brightBlack: Color(0xFF374151),
                    brightRed: Color(0xFFEF4444),
                    brightGreen: Color(0xFF22C55E),
                    brightYellow: Color(0xFFEAB308),
                    brightBlue: Color(0xFF3B82F6),
                    brightMagenta: Color(0xFFEC4899),
                    brightCyan: Color(0xFF06B6D4),
                    brightWhite: Color(0xFFF9FAFB),
                    searchHitBackground: Color(0x66FACC15),
                    searchHitBackgroundCurrent: Color(0xAAEAB308),
                    searchHitForeground: Color(0xFF111827),
                  ),
                  padding: const EdgeInsets.all(12),
                  autofocus: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Direct terminal input enabled. Press Enter to send command.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton(
                onPressed: () => widget.onDeleteSession(active.session.id),
                child: const Text('Delete Session'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _syncTerminals(List<SessionView> sessions) {
    final liveIds = sessions.map((item) => item.session.id).toSet();
    final removedIds = _terminals.keys
        .where((id) => !liveIds.contains(id))
        .toList(growable: false);

    for (final id in removedIds) {
      _terminals.remove(id);
      _renderedLineCount.remove(id);
      _pendingInput.remove(id);
    }

    for (final session in sessions) {
      final id = session.session.id;
      final terminal = _terminals.putIfAbsent(id, () {
        final created = Terminal(maxLines: 5000);
        created.onOutput = (data) => _handleTerminalOutput(id, data);
        return created;
      });

      final rendered = _renderedLineCount[id] ?? 0;
      if (session.output.length < rendered) {
        terminal.write('\x1b[2J\x1b[H');
        for (final line in session.output) {
          terminal.write('$line\r\n');
        }
        _renderedLineCount[id] = session.output.length;
        continue;
      }

      if (session.output.length == rendered) {
        continue;
      }

      for (var i = rendered; i < session.output.length; i += 1) {
        terminal.write('${session.output[i]}\r\n');
      }
      _renderedLineCount[id] = session.output.length;
    }
  }

  void _handleTerminalOutput(String sessionId, String data) {
    final terminal = _terminals[sessionId];
    if (terminal == null) {
      return;
    }

    final inputBuffer = _pendingInput.putIfAbsent(sessionId, StringBuffer.new);
    final codePoints = data.runes.toList(growable: false);

    for (final codePoint in codePoints) {
      if (codePoint == 13 || codePoint == 10) {
        final command = inputBuffer.toString();
        inputBuffer.clear();
        terminal.write('\r\n');
        if (command.trim().isNotEmpty) {
          widget.onSendInput(sessionId, command);
        }
        continue;
      }

      if (codePoint == 8 || codePoint == 127) {
        final current = inputBuffer.toString();
        if (current.isNotEmpty) {
          inputBuffer.clear();
          inputBuffer.write(current.substring(0, current.length - 1));
          terminal.write('\b \b');
        }
        continue;
      }

      if (codePoint < 32) {
        continue;
      }

      final char = String.fromCharCode(codePoint);
      inputBuffer.write(char);
      terminal.write(char);
    }
  }
}
