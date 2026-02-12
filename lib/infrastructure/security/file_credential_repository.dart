import 'dart:convert';
import 'dart:io';

import 'package:small_ssh/domain/models/credential_ref.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';

class FileCredentialRepository implements CredentialRepository {
  FileCredentialRepository({String? filePath}) : _filePath = filePath;

  final String? _filePath;
  Map<String, String>? _items;

  @override
  Future<String?> readSecret(CredentialRef credentialRef) async {
    await _ensureLoaded();
    return _items![credentialRef.id];
  }

  @override
  Future<void> writeSecret(
    CredentialRef credentialRef,
    String secret,
  ) async {
    await _ensureLoaded();
    final trimmed = secret.trim();
    if (trimmed.isEmpty) {
      _items!.remove(credentialRef.id);
    } else {
      _items![credentialRef.id] = secret;
    }
    await _persist();
  }

  Future<void> _ensureLoaded() async {
    if (_items != null) {
      return;
    }
    final file = _storageFile;
    if (!await file.exists()) {
      _items = <String, String>{};
      await _persist();
      return;
    }

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Expected a map');
      }
      _items = decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      _items = <String, String>{};
      await _persist();
    }
  }

  Future<void> _persist() async {
    final file = _storageFile;
    await file.writeAsString(jsonEncode(_items), flush: true);
  }

  File get _storageFile {
    if (_filePath != null && _filePath!.isNotEmpty) {
      return File(_filePath!);
    }
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final separator = Platform.pathSeparator;
    return File('$executableDir${separator}credentials.json');
  }
}
