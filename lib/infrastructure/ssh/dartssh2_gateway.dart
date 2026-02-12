import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:small_ssh/domain/models/auth_method.dart';
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

}
