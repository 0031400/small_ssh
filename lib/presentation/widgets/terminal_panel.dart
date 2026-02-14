import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:small_ssh/app/settings.dart';
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
    required this.onResizeTerminal,
    required this.settings,
  });

  final List<SessionView> sessions;
  final String? activeSessionId;
  final Future<void> Function(String sessionId) onDeleteSession;
  final Future<void> Function(String sessionId, String input) onSendInput;
  final Future<void> Function(
    String sessionId,
    int width,
    int height, {
    int pixelWidth,
    int pixelHeight,
  })
  onResizeTerminal;
  final void Function(String sessionId) onSelectSession;
  final AppSettings settings;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  final Map<String, Terminal> _terminals = <String, Terminal>{};
  final Map<String, TerminalController> _controllers =
      <String, TerminalController>{};
  final Map<String, int> _renderedLineCount = <String, int>{};
  final Map<String, _TerminalGridSize> _lastSyncedGridSize =
      <String, _TerminalGridSize>{};

  @override
  void dispose() {
    _terminals.clear();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _renderedLineCount.clear();
    _lastSyncedGridSize.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sessions.isEmpty) {
      final textTheme = Theme.of(context).textTheme;
      return Center(
        child: Text(
          'No active session. Choose a host and connect.',
          style: textTheme.bodyMedium,
        ),
      );
    }

    final active = widget.sessions.firstWhere(
      (session) => session.session.id == widget.activeSessionId,
      orElse: () => widget.sessions.first,
    );
    _syncTerminals(widget.sessions);
    final terminal = _terminals[active.session.id]!;
    final controller = _controllers[active.session.id]!;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.sessions.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
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
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                child: TerminalView(
                  terminal,
                  hardwareKeyboardOnly: true,
                  controller: controller,
                  textStyle: TerminalStyle(
                    fontSize: widget.settings.terminalFontSize,
                  ),
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
                  padding: const EdgeInsets.all(8),
                  autofocus: true,
                  onSecondaryTapUp: (details, _) {
                    _handleTerminalSecondaryTap(
                      details,
                      terminal,
                      controller,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Direct terminal input enabled. Press Enter to send command.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Delete session',
                visualDensity: VisualDensity.compact,
                onPressed: () => widget.onDeleteSession(active.session.id),
                icon: const Icon(Icons.delete_outline),
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
      _controllers.remove(id)?.dispose();
      _renderedLineCount.remove(id);
      _lastSyncedGridSize.remove(id);
    }

    for (final session in sessions) {
      final id = session.session.id;
      _controllers.putIfAbsent(id, () => TerminalController());
      final terminal = _terminals.putIfAbsent(id, () {
        final created = Terminal(maxLines: 5000);
        created.onOutput = (data) => widget.onSendInput(id, data);
        created.onResize = (width, height, pixelWidth, pixelHeight) {
          widget.onResizeTerminal(
            id,
            width,
            height,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
          );
        };
        return created;
      });
      _syncTerminalGridSize(id, terminal);

      final rendered = _renderedLineCount[id] ?? 0;
      if (session.output.length < rendered) {
        terminal.write('\x1b[2J\x1b[H');
        for (final chunk in session.output) {
          terminal.write(chunk);
        }
        _renderedLineCount[id] = session.output.length;
        continue;
      }

      if (session.output.length == rendered) {
        continue;
      }

      for (var i = rendered; i < session.output.length; i += 1) {
        terminal.write(session.output[i]);
      }
      _renderedLineCount[id] = session.output.length;
    }
  }

  void _syncTerminalGridSize(String sessionId, Terminal terminal) {
    final width = terminal.viewWidth;
    final height = terminal.viewHeight;
    if (width <= 0 || height <= 0) {
      return;
    }

    final next = _TerminalGridSize(width: width, height: height);
    if (_lastSyncedGridSize[sessionId] == next) {
      return;
    }

    _lastSyncedGridSize[sessionId] = next;
    widget.onResizeTerminal(sessionId, width, height);
  }

  Future<void> _handleTerminalSecondaryTap(
    TapUpDetails details,
    Terminal terminal,
    TerminalController controller,
  ) async {
    final selection = controller.selection;
    final selectedText =
        selection == null ? null : terminal.buffer.getText(selection);
    final hasSelection = selectedText != null && selectedText.isNotEmpty;

    if (widget.settings.clipboardBehavior == ClipboardBehavior.direct) {
      if (hasSelection) {
        await Clipboard.setData(ClipboardData(text: selectedText));
      } else {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text;
        if (text != null && text.isNotEmpty) {
          terminal.paste(text);
          controller.clearSelection();
        }
      }
      return;
    }

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<_TerminalMenuAction>(
      context: context,
      position: position,
      items: [
        if (hasSelection)
          const PopupMenuItem(
            value: _TerminalMenuAction.copy,
            child: Text('Copy'),
          )
        else
          const PopupMenuItem(
            value: _TerminalMenuAction.paste,
            child: Text('Paste'),
          ),
      ],
    );

    if (action == _TerminalMenuAction.copy && hasSelection) {
      await Clipboard.setData(ClipboardData(text: selectedText));
      return;
    }

    if (action == _TerminalMenuAction.paste) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text != null && text.isNotEmpty) {
        terminal.paste(text);
        controller.clearSelection();
      }
    }
  }
}

enum _TerminalMenuAction { copy, paste }

class _TerminalGridSize {
  const _TerminalGridSize({required this.width, required this.height});

  final int width;
  final int height;

  @override
  bool operator ==(Object other) {
    return other is _TerminalGridSize &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(width, height);
}
