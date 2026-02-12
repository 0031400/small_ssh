import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:small_ssh/domain/models/auth_method.dart';
import 'package:small_ssh/domain/models/sftp_entry.dart';
import 'package:small_ssh/infrastructure/ssh/ssh_gateway.dart';

class DartSsh2Gateway implements SshGateway {
  int _counter = 0;

  @override
  Future<SshConnection> connect(SshConnectRequest request) async {
    final socket = await SSHSocket.connect(request.host, request.port);

    List<SSHKeyPair>? identities;
    final privateKey = _normalizePem(request.privateKey);
    if (request.authMethod == AuthMethod.privateKey &&
        privateKey != null &&
        privateKey.isNotEmpty) {
      identities = SSHKeyPair.fromPem(
        privateKey,
        request.privateKeyPassphrase,
      );
    }

    final password = request.password;
    final passwordProvider = request.authMethod == AuthMethod.password
        ? () {
            final value = password;
            return (value == null || value.trim().isEmpty) ? null : value;
          }
        : null;

    final interactivePassword = request.authMethod ==
            AuthMethod.keyboardInteractive
        ? request.keyboardInteractivePassword
        : null;

    final client = SSHClient(
      socket,
      username: request.username,
      identities: identities,
      onPasswordRequest: passwordProvider,
      onUserInfoRequest: interactivePassword == null
          ? null
          : (request) {
              final value = interactivePassword.trim();
              if (value.isEmpty) {
                return null;
              }
              return List<String>.filled(request.prompts.length, value);
            },
      // TODO: replace this with known_hosts verification flow.
      onVerifyHostKey: (keyType, fingerprint) => true,
    );

    final shell = await client.shell();

    _counter += 1;
    return _DartSsh2Connection(
      id: 'session-$_counter',
      client: client,
      shell: shell,
    );
  }

  String? _normalizePem(String? pem) {
    if (pem == null) {
      return null;
    }
    final trimmed = pem.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.replaceAll('\r\n', '\n');
  }
}

class _DartSsh2Connection implements SshConnection {
  _DartSsh2Connection({
    required this.id,
    required SSHClient client,
    required SSHSession shell,
  }) : _client = client,
       _shell = shell {
    _stdoutSub = _shell.stdout.listen(_handleChunk, onDone: _closeOutput);
    _stderrSub = _shell.stderr.listen(_handleChunk, onDone: _closeOutput);
  }

  @override
  final String id;

  final SSHClient _client;
  final SSHSession _shell;
  SftpClient? _sftpClient;
  Future<SftpClient>? _sftpOpening;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();

  StreamSubscription<Uint8List>? _stdoutSub;
  StreamSubscription<Uint8List>? _stderrSub;

  @override
  Stream<String> get output => _outputController.stream;

  @override
  Future<void> sendInput(String input) async {
    if (input.isEmpty) {
      return;
    }

    _shell.write(Uint8List.fromList(utf8.encode(input)));
  }

  @override
  Future<void> disconnect() async {
    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _sftpClient?.close();
    _shell.close();
    _client.close();
    _closeOutput();
  }

  void _handleChunk(Uint8List chunk) {
    final text = utf8.decode(chunk, allowMalformed: true);
    if (text.isNotEmpty && !_outputController.isClosed) {
      _outputController.add(text);
    }
  }

  void _closeOutput() {
    if (!_outputController.isClosed) {
      _outputController.close();
    }
  }

  @override
  Future<void> resizeTerminal(
    int width,
    int height, {
    int pixelWidth = 0,
    int pixelHeight = 0,
  }) async {
    _shell.resizeTerminal(width, height, pixelWidth, pixelHeight);
  }

  @override
  Future<String> resolveSftpHome() async {
    final sftp = await _openSftp();
    return sftp.absolute('.');
  }

  @override
  Future<List<SftpEntry>> listSftpDirectory(String path) async {
    final sftp = await _openSftp();
    final entries = await sftp.listdir(path);
    final normalized = path.isEmpty ? '/' : path;
    final results = <SftpEntry>[];
    for (final entry in entries) {
      if (entry.filename == '.' || entry.filename == '..') {
        continue;
      }
      results.add(
        SftpEntry(
          name: entry.filename,
          path: _joinRemote(normalized, entry.filename),
          isDirectory: entry.attr.isDirectory,
          size: entry.attr.size,
        ),
      );
    }
    results.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return results;
  }

  @override
  Future<void> downloadSftpFile({
    required String remotePath,
    required String localPath,
  }) async {
    final sftp = await _openSftp();
    final file = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    final bytes = await file.readBytes();
    await file.close();
    final localFile = File(localPath);
    await localFile.parent.create(recursive: true);
    await localFile.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<void> uploadSftpFile({
    required String localPath,
    required String remotePath,
  }) async {
    final localFile = File(localPath);
    if (!await localFile.exists()) {
      throw StateError('Local file not found: $localPath');
    }
    final sftp = await _openSftp();
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.write |
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate,
    );
    final writer = file.write(
      localFile.openRead().map((chunk) => Uint8List.fromList(chunk)),
    );
    await writer.done;
    await file.close();
  }

  Future<SftpClient> _openSftp() {
    if (_sftpClient != null) {
      return Future<SftpClient>.value(_sftpClient);
    }
    final pending = _sftpOpening;
    if (pending != null) {
      return pending;
    }
    final opening = _client.sftp().then((client) {
      _sftpClient = client;
      return client;
    });
    _sftpOpening = opening;
    return opening;
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
}
