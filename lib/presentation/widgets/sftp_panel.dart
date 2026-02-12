import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _pathController = TextEditingController();
  final FocusNode _pathFocusNode = FocusNode();
  bool _editingPath = false;
  List<SftpEntry> _entries = <SftpEntry>[];
  bool _loading = false;
  String? _error;
  final Set<String> _selectedPaths = <String>{};
  int? _lastSelectedIndex;
  bool _available = true;
  bool _dragging = false;
  bool _transferActive = false;
  String? _transferLabel;
  double? _transferProgress;
  DateTime? _lastProgressPaint;
  bool _cancelRequested = false;

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
    _pathFocusNode.addListener(() {
      if (!_pathFocusNode.hasFocus && _editingPath) {
        setState(() => _editingPath = false);
      }
    });
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocusNode.dispose();
    super.dispose();
  }

  void _handleSessionChange() {
    _sessionId = widget.activeSessionId;
    _selectedPaths.clear();
    _entries = <SftpEntry>[];
    _currentPath = null;
    _pathController.text = '';
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

  Future<bool> _loadDirectory(
    String path, {
    bool markUnavailableOnError = true,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null) {
      return false;
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
      if (!mounted) return Future.value(false);
      setState(() {
        _entries = entries;
        _currentPath = path;
        if (!_editingPath) {
          _pathController.text = path;
        }
        _selectedPaths.clear();
        _lastSelectedIndex = null;
        _loading = false;
        _available = true;
      });
      widget.onAvailabilityChanged?.call(true);
      return true;
    } catch (error) {
      if (!mounted) return Future.value(false);
      setState(() {
        _loading = false;
        _error = error.toString();
        if (markUnavailableOnError) {
          _available = false;
        }
      });
      if (markUnavailableOnError) {
        widget.onAvailabilityChanged?.call(false);
      }
      return false;
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
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final index = trimmed.lastIndexOf('/');
    if (index <= 0) {
      return '/';
    }
    return trimmed.substring(0, index);
  }

  List<String> _pathSuggestions(String path) {
    if (path.isEmpty) {
      return const ['/'];
    }
    final current = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final parent = _parentPath(current);
    final grand = parent == '/' ? '/' : _parentPath(parent);
    final suggestions = <String>{current, parent, grand};
    return suggestions.toList();
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
    if (sessionId == null) {
      return;
    }
    if (_selectedPaths.isEmpty) {
      return;
    }
    final selectedEntries = _entries
        .where((entry) => _selectedPaths.contains(entry.path))
        .toList(growable: false);
    final filesOnly = selectedEntries
        .where((entry) => !entry.isDirectory)
        .toList();
    if (filesOnly.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only files can be downloaded.')),
      );
      return;
    }
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select download folder',
    );
    if (directory == null || directory.trim().isEmpty) {
      return;
    }
    try {
      for (final entry in filesOnly) {
        if (_cancelRequested) {
          break;
        }
        _startTransfer('Downloading', entry.name);
        final localPath = _joinLocal(directory.trim(), entry.name);
        await widget.orchestrator.downloadSftpFile(
          sessionId: sessionId,
          remotePath: entry.path,
          localPath: localPath,
          onProgress: (transferred, total) {
            _updateTransferProgress(transferred, total);
          },
          shouldCancel: () => _cancelRequested,
        );
      }
      if (!mounted) return;
      _finishTransfer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Download completed.')));
    } catch (error) {
      if (!mounted) return;
      _finishTransfer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
    }
  }

  Future<void> _uploadFromLocal() async {
    final sessionId = _sessionId;
    final current = _currentPath;
    if (sessionId == null || current == null) {
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select file to upload',
      allowMultiple: false,
    );
    if (!mounted) {
      return;
    }
    final localPath = picked?.files.single.path;
    if (localPath == null || localPath.trim().isEmpty) {
      return;
    }
    final fileName = _basename(localPath.trim());
    final remotePath = _joinRemote(current, fileName);
    try {
      _startTransfer('Uploading', fileName);
      await widget.orchestrator.uploadSftpFile(
        sessionId: sessionId,
        localPath: localPath.trim(),
        remotePath: remotePath,
        onProgress: (transferred, total) {
          _updateTransferProgress(transferred, total);
        },
        shouldCancel: () => _cancelRequested,
      );
      if (!mounted) return;
      _finishTransfer();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload completed.')));
    } catch (error) {
      if (!mounted) return;
      _finishTransfer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    }
  }

  Future<void> _uploadDroppedFiles(List<DropItem> files) async {
    final sessionId = _sessionId;
    final current = _currentPath;
    if (sessionId == null || current == null || files.isEmpty) {
      return;
    }
    try {
      for (final item in files) {
        if (_cancelRequested) {
          break;
        }
        final localPath = item.path;
        if (localPath.isEmpty) {
          continue;
        }
        final fileName = _basename(localPath);
        final remotePath = _joinRemote(current, fileName);
        _startTransfer('Uploading', fileName);
        await widget.orchestrator.uploadSftpFile(
          sessionId: sessionId,
          localPath: localPath,
          remotePath: remotePath,
          onProgress: (transferred, total) {
            _updateTransferProgress(transferred, total);
          },
          shouldCancel: () => _cancelRequested,
        );
      }
      if (!mounted) return;
      _finishTransfer();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload completed.')));
    } catch (error) {
      if (!mounted) return;
      _finishTransfer();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    }
  }

  Future<void> _createFolder() async {
    final sessionId = _sessionId;
    final current = _currentPath;
    if (sessionId == null || current == null) {
      return;
    }
    final name = await _promptForText(
      title: 'New Folder',
      hint: 'folder-name',
      actionLabel: 'Create',
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final remotePath = _joinRemote(current, name.trim());
    try {
      await widget.orchestrator.createSftpDirectory(
        sessionId: sessionId,
        path: remotePath,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Folder created.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create folder failed: $error')));
    }
  }

  Future<void> _deleteSelected() async {
    final sessionId = _sessionId;
    if (sessionId == null || _selectedPaths.isEmpty) {
      return;
    }
    final confirmed = await _confirmDelete(
      _selectedPaths.length == 1
          ? 'Delete selected item?'
          : 'Delete ${_selectedPaths.length} items?',
    );
    if (confirmed != true) {
      return;
    }
    try {
      for (final path in _selectedPaths) {
        final entry = _entries.firstWhere(
          (item) => item.path == path,
          orElse: () => const SftpEntry(name: '', path: '', isDirectory: false),
        );
        if (entry.path.isEmpty) {
          continue;
        }
        await widget.orchestrator.deleteSftpEntry(
          sessionId: sessionId,
          path: entry.path,
          isDirectory: entry.isDirectory,
        );
      }
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $error')));
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

  String _joinLocal(String base, String name) {
    if (base.endsWith('\\') || base.endsWith('/')) {
      return '$base$name';
    }
    return '$base\\$name';
  }

  void _startTransfer(String action, String name) {
    _transferActive = true;
    _transferLabel = '$action: $name';
    _transferProgress = 0;
    _lastProgressPaint = null;
    _cancelRequested = false;
    setState(() {});
  }

  void _updateTransferProgress(int transferred, int total) {
    if (total <= 0) {
      return;
    }
    final now = DateTime.now();
    if (_lastProgressPaint != null &&
        now.difference(_lastProgressPaint!).inMilliseconds < 100) {
      return;
    }
    _lastProgressPaint = now;
    setState(() {
      _transferProgress = transferred / total;
    });
  }

  void _finishTransfer() {
    _transferActive = false;
    _transferLabel = null;
    _transferProgress = null;
    _lastProgressPaint = null;
    _cancelRequested = false;
    setState(() {});
  }

  void _cancelTransfer() {
    if (!_transferActive) {
      return;
    }
    _cancelRequested = true;
    setState(() {});
  }

  Future<String?> _promptForText({
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
            decoration: InputDecoration(labelText: 'Name', hintText: hint),
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

  Future<bool?> _confirmDelete(String message) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete'),
          content: Text(message),
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
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.orchestrator.activeSession;
    final isConnected =
        session?.session.status == ConnectionStateStatus.connected;
    final path = _currentPath ?? '/';
    if (isConnected &&
        _sessionId != null &&
        _currentPath == null &&
        !_loading) {
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
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('SFTP', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    tooltip: 'New Folder',
                    visualDensity: VisualDensity.compact,
                    onPressed: !isConnected || _loading ? null : _createFolder,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        !isConnected || _loading || _selectedPaths.isEmpty
                        ? null
                        : _deleteSelected,
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Up',
                    visualDensity: VisualDensity.compact,
                    onPressed: !isConnected || _loading || path == '/'
                        ? null
                        : () => _loadDirectory(_parentPath(path)),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    visualDensity: VisualDensity.compact,
                    onPressed: !isConnected || _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
                ],
              ),
              if (_transferActive) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _transferLabel ?? 'Transferring...',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: _cancelRequested ? null : _cancelTransfer,
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: _transferProgress),
              ],
              RawAutocomplete<String>(
                textEditingController: _pathController,
                focusNode: _pathFocusNode,
                optionsBuilder: (value) {
                  final input = value.text.trim();
                  final base = input.isEmpty ? path : input;
                  return _pathSuggestions(base);
                },
                displayStringForOption: (option) => option,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        onTap: () => setState(() => _editingPath = true),
                        onSubmitted: (value) async {
                          final next = value.trim();
                          setState(() => _editingPath = false);
                          if (next.isNotEmpty) {
                            final previous = _currentPath ?? '';
                            final ok = await _loadDirectory(
                              next,
                              markUnavailableOnError: false,
                            );
                            if (!ok) {
                              _pathController.text = previous;
                            }
                          } else {
                            _pathController.text = _currentPath ?? '';
                          }
                        },
                      );
                    },
                optionsViewBuilder:
                    (context, onSelected, Iterable<String> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                onSelected: (value) async {
                  setState(() => _editingPath = false);
                  final previous = _currentPath ?? '';
                  final ok = await _loadDirectory(
                    value,
                    markUnavailableOnError: false,
                  );
                  if (!ok) {
                    _pathController.text = previous;
                  }
                },
              ),
              const SizedBox(height: 6),
              DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: (details) async {
                  setState(() => _dragging = false);
                  if (!isConnected || _loading) {
                    return;
                  }
                  if (details.files.isEmpty) {
                    return;
                  }
                  await _uploadDroppedFiles(details.files);
                },
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _dragging
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _dragging
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    'Drag files here to upload',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    tooltip: 'Download',
                    onPressed:
                        !isConnected || _loading || _selectedPaths.isEmpty
                        ? null
                        : _downloadSelected,
                    icon: const Icon(Icons.download, size: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Upload',
                    onPressed: !isConnected || _loading
                        ? null
                        : _uploadFromLocal,
                    icon: const Icon(Icons.upload_file, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildContent(isConnected)),
      ],
    );
  }

  Widget _buildContent(bool isConnected) {
    if (!isConnected) {
      return const Center(child: Text('Connect to a host to browse files.'));
    }
    if (_loading && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
      );
    }
    if (_entries.isEmpty) {
      return const Center(child: Text('No files'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(6),
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isSelected = _selectedPaths.contains(entry.path);
        return InkWell(
          onTap: () {
            final keys = HardwareKeyboard.instance.logicalKeysPressed;
            final shiftPressed =
                keys.contains(LogicalKeyboardKey.shiftLeft) ||
                keys.contains(LogicalKeyboardKey.shiftRight);
            final ctrlPressed =
                keys.contains(LogicalKeyboardKey.controlLeft) ||
                keys.contains(LogicalKeyboardKey.controlRight) ||
                keys.contains(LogicalKeyboardKey.metaLeft) ||
                keys.contains(LogicalKeyboardKey.metaRight);
            setState(() {
              if (shiftPressed && _lastSelectedIndex != null) {
                final start = _lastSelectedIndex!;
                final end = index;
                final min = start < end ? start : end;
                final max = start < end ? end : start;
                if (!ctrlPressed) {
                  _selectedPaths.clear();
                }
                for (var i = min; i <= max; i += 1) {
                  _selectedPaths.add(_entries[i].path);
                }
              } else if (ctrlPressed) {
                if (_selectedPaths.contains(entry.path)) {
                  _selectedPaths.remove(entry.path);
                } else {
                  _selectedPaths.add(entry.path);
                }
                _lastSelectedIndex = index;
              } else {
                _selectedPaths
                  ..clear()
                  ..add(entry.path);
                _lastSelectedIndex = index;
              }
            });
          },
          onDoubleTap: entry.isDirectory
              ? () => _loadDirectory(entry.path)
              : null,
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            selected: isSelected,
            leading: Icon(
              entry.isDirectory
                  ? Icons.folder
                  : Icons.insert_drive_file_outlined,
              size: 18,
            ),
            title: Text(entry.name, overflow: TextOverflow.ellipsis),
            subtitle: entry.isDirectory
                ? const Text('Folder')
                : Text(_formatSize(entry.size)),
            trailing: entry.isDirectory
                ? IconButton(
                    tooltip: 'Open',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_forward_ios, size: 14),
                    onPressed: () => _loadDirectory(entry.path),
                  )
                : null,
          ),
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
