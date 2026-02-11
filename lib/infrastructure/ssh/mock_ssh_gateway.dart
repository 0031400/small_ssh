import 'dart:async';

import 'package:small_ssh/infrastructure/ssh/ssh_gateway.dart';

class MockSshGateway implements SshGateway {
  int _counter = 0;

  @override
  Future<SshConnection> connect(SshConnectRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (request.host.trim().isEmpty) {
      throw Exception('Host is empty');
    }

    _counter += 1;
    return _MockSshConnection(id: 'session-$_counter', request: request);
  }
}

class _MockSshConnection implements SshConnection {
  _MockSshConnection({required this.id, required this.request}) {
    _emit('Connected to ${request.username}@${request.host}:${request.port}');
    _emit('Mock shell ready. Type and press Enter.');
  }

  @override
  final String id;
  final SshConnectRequest request;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();

  @override
  Stream<String> get output => _outputController.stream;

  @override
  Future<void> sendInput(String input) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return;
    }

    if (trimmed == 'clear') {
      _emit('[screen cleared in real terminal]');
      return;
    }

    if (trimmed == 'exit') {
      _emit('Session closing...');
      await disconnect();
      return;
    }

    _emit('\$ $trimmed');
    _emit('echo: $trimmed');
  }

  @override
  Future<void> disconnect() async {
    if (!_outputController.isClosed) {
      _emit('Disconnected.');
      await _outputController.close();
    }
  }

  void _emit(String line) {
    if (!_outputController.isClosed) {
      _outputController.add(line);
    }
  }
}
