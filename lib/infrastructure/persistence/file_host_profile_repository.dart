import 'dart:convert';
import 'dart:io';

import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/domain/repositories/host_profile_repository.dart';

class FileHostProfileRepository implements HostProfileRepository {
  FileHostProfileRepository({String? filePath}) : _filePath = filePath;

  final String? _filePath;
  Map<String, HostProfile>? _items;

  static const List<HostProfile> _defaultHosts = <HostProfile>[
    HostProfile(
      id: 'local-dev',
      name: 'Local Dev Server',
      host: '127.0.0.1',
      port: 22,
      username: 'developer',
      privateKeyMode: PrivateKeyMode.global,
    ),
    HostProfile(
      id: 'demo-box',
      name: 'Demo Host',
      host: '192.168.1.100',
      port: 22,
      username: 'root',
      privateKeyMode: PrivateKeyMode.global,
    ),
  ];

  @override
  Future<HostProfile?> findById(String id) async {
    await _ensureLoaded();
    return _items![id];
  }

  @override
  Future<List<HostProfile>> getAll() async {
    await _ensureLoaded();
    return _items!.values.toList(growable: false);
  }

  @override
  Future<void> save(HostProfile profile) async {
    await _ensureLoaded();
    _items![profile.id] = profile;
    await _persist();
  }

  @override
  Future<void> deleteById(String id) async {
    await _ensureLoaded();
    _items!.remove(id);
    await _persist();
  }

  Future<void> _ensureLoaded() async {
    if (_items != null) {
      return;
    }

    final file = _storageFile;
    if (!await file.exists()) {
      _items = <String, HostProfile>{
        for (final host in _defaultHosts) host.id: host,
      };
      await _persist();
      return;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Expected a list');
      }

      final map = <String, HostProfile>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final json = item.cast<String, dynamic>();
        final profile = HostProfile(
          id: (json['id'] ?? '').toString(),
          name: (json['name'] ?? '').toString(),
          host: (json['host'] ?? '').toString(),
          port: (json['port'] as num?)?.toInt() ?? 22,
          username: (json['username'] ?? '').toString(),
          privateKeyMode: _parsePrivateKeyMode(json['privateKeyMode']),
        );
        if (profile.id.isEmpty ||
            profile.name.isEmpty ||
            profile.host.isEmpty ||
            profile.username.isEmpty) {
          continue;
        }
        map[profile.id] = profile;
      }

      _items = map;
    } catch (_) {
      _items = <String, HostProfile>{
        for (final host in _defaultHosts) host.id: host,
      };
      await _persist();
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    final payload = _items!.values
        .map(
          (host) => <String, Object>{
            'id': host.id,
            'name': host.name,
            'host': host.host,
            'port': host.port,
            'username': host.username,
            'privateKeyMode': host.privateKeyMode.name,
          },
        )
        .toList(growable: false);

    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  File get _storageFile {
    final path = _filePath;
    if (path != null && path.isNotEmpty) {
      return File(path);
    }
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final separator = Platform.pathSeparator;
    return File('$executableDir${separator}hosts.json');
  }

  PrivateKeyMode _parsePrivateKeyMode(Object? value) {
    if (value is String) {
      for (final mode in PrivateKeyMode.values) {
        if (mode.name == value) {
          return mode;
        }
      }
    }
    return PrivateKeyMode.global;
  }
}
