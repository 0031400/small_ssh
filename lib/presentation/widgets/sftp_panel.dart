import 'package:flutter/material.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/domain/models/connection_state_status.dart';
import 'package:small_ssh/domain/models/sftp_entry.dart';

class SftpPanel extends StatefulWidget {
  const SftpPanel({
    super.key,
    required this.orchestrator,
    required this.activeSessionId,
    this.onAvailabilityChanged,
  });

  final SessionOrchestrator orchestrator;
  final String? activeSessionId;
  final ValueChanged<bool>? onAvailabilityChanged;

  @override
  State<SftpPanel> createState() => _SftpPanelState();
}

class _SftpPanelState extends State<SftpPanel> {
  String? _sessionId;
  String? _currentPath;
  List<SftpEntry> _entries = <SftpEntry>[];
  bool _loading = false;
  String? _error;
  SftpEntry? _selected;
  bool _available = true;

  @override
  void didUpdateWidget(covariant SftpPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSessionId != widget.activeSessionId) {
      _handleSessionChange();
    }
  }

  @override
  void initState() {
    super.initState();
    _handleSessionChange();
  }

  void _handleSessionChange() {
    _sessionId = widget.activeSessionId;
    _selected = null;
    _entries = <SftpEntry>[];
    _currentPath = null;
    _error = null;
    _available = true;
    if (_sessionId == null) {
      widget.onAvailabilityChanged?.call(false);
      setState(() {});
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadHome() async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    setState(() => _loading = true);
    try {
      final home = await widget.orchestrator.resolveSftpHome(sessionId);
      if (!mounted) return;
      if (home == null) {
        setState(() {
          _loading = false;
          _error = 'SFTP unavailable for this session.';
          _available = false;
        });
        widget.onAvailabilityChanged?.call(false);
        return;
      }
      _available = true;
      widget.onAvailabilityChanged?.call(true);
      await _loadDirectory(home);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _available = false;
      });
      widget.onAvailabilityChanged?.call(false);
    }
  }

  Future<void> _loadDirectory(String path) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.orchestrator.listSftpDirectory(
        sessionId,
        path,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _currentPath = path;
        _selected = null;
        _loading = false;
        _available = true;
      });
      widget.onAvailabilityChanged?.call(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
        _available = false;
      });
      widget.onAvailabilityChanged?.call(false);
    }
  }

  Future<void> _refresh() async {
    final path = _currentPath;
    if (path == null) {
      return;
    }
    await _loadDirectory(path);
  }

  String _parentPath(String path) {
    if (path.isEmpty || path == '/') {
      return '/';
    }
    final trimmed = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final index = trimmed.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return trimmed.substring(0, index);
  }

  String _joinRemote(String base, String name) {
    if (base.isEmpty || base == '/') {
      return '/$name';
    }
    if (base.endsWith('/')) {
      return '$base$name';
    }
    return '$base/$name';
  }

  Future<void> _downloadSelected() async {
    final sessionId = _sessionId;
    final selected = _selected;
    if (sessionId == null || selected == null || selected.isDirectory) {
      return;
    }
    final localPath = await _promptForPath(
      title: 'Copy to Local',
      hint: 'C:\\path\\to\\${selected.name}',
      actionLabel: 'Copy',
    );
    if (localPath == null || localPath.trim().isEmpty) {
      return;
    }
    try {
      await widget.orchestrator.downloadSftpFile(
        sessionId: sessionId,
        remotePath: selected.path,
        localPath: localPath.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download completed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    }
  }

  Future<void> _uploadFromLocal() async {
    final sessionId = _sessionId;
    final current = _currentPath;
    if (sessionId == null || current == null) {
      return;
    }
    final localPath = await _promptForPath(
      title: 'Paste from Local',
      hint: 'C:\\path\\to\\file.txt',
      actionLabel: 'Paste',
    );
    if (localPath == null || localPath.trim().isEmpty) {
      return;
    }
    final fileName = _basename(localPath.trim());
    final remotePath = _joinRemote(current, fileName);
    try {
      await widget.orchestrator.uploadSftpFile(
        sessionId: sessionId,
        localPath: localPath.trim(),
        remotePath: remotePath,
      );
      if (!mounted) return;
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload completed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    }
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0) {
      return normalized;
    }
    return normalized.substring(index + 1);
  }

  Future<String?> _promptForPath({
    required String title,
    required String hint,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Local path',
              hintText: hint,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.orchestrator.activeSession;
    final isConnected = session?.session.status == ConnectionStateStatus.connected;
    final path = _currentPath ?? '/';
    if (isConnected && _sessionId != null && _currentPath == null && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadHome();
        }
      });
    }

    if (!_available) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text('SFTP', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Up',
                    onPressed: !isConnected || _loading || path == '/'
                        ? null
                        : () => _loadDirectory(_parentPath(path)),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: !isConnected || _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Text(
                path,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !isConnected || _loading
                          ? null
                          : _uploadFromLocal,
                      icon: const Icon(Icons.paste),
                      label: const Text('Paste'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !isConnected ||
                              _loading ||
                              _selected == null ||
                              _selected!.isDirectory
                          ? null
                          : _downloadSelected,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _buildContent(isConnected),
        ),
      ],
    );
  }

  Widget _buildContent(bool isConnected) {
    if (!isConnected) {
      return const Center(
        child: Text('Connect to a host to browse files.'),
      );
    }
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_error!),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('No files'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isSelected = _selected?.path == entry.path;
        return ListTile(
          dense: true,
          selected: isSelected,
          leading: Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
            size: 18,
          ),
          title: Text(
            entry.name,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: entry.isDirectory
              ? const Text('Folder')
              : Text(_formatSize(entry.size)),
          onTap: () {
            if (entry.isDirectory) {
              _loadDirectory(entry.path);
            } else {
              setState(() => _selected = entry);
            }
          },
        );
      },
    );
  }

  String _formatSize(int? size) {
    if (size == null) {
      return 'Unknown size';
    }
    if (size < 1024) {
      return '$size B';
    }
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
