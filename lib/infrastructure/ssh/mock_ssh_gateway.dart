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
    _emit('Connected to ${request.username}@${request.host}:${request.port}\r\n');
    _emit('Mock shell ready. Type and press Enter.\r\n');
  }

  @override
  final String id;
  final SshConnectRequest request;

  final StreamController<String> _outputController =
      StreamController<String>.broadcast();
  final StringBuffer _inputBuffer = StringBuffer();

  @override
  Stream<String> get output => _outputController.stream;

  @override
  Future<void> sendInput(String input) async {
    if (input.isEmpty) {
      return;
    }

    for (final rune in input.runes) {
      if (rune == 3) {
        _emit('^C\r\n');
        _inputBuffer.clear();
        continue;
      }

      if (rune == 27) {
        _emit('^[',);
        continue;
      }

      if (rune == 8 || rune == 127) {
        if (_inputBuffer.isNotEmpty) {
          final current = _inputBuffer.toString();
          _inputBuffer
            ..clear()
            ..write(current.substring(0, current.length - 1));
          _emit('\b \b');
        }
        continue;
      }

      if (rune == 13 || rune == 10) {
        final command = _inputBuffer.toString().trim();
        _inputBuffer.clear();
        _emit('\r\n');
        if (command.isEmpty) {
          continue;
        }

        if (command == 'clear') {
          _emit('\x1b[2J\x1b[H');
          continue;
        }

        if (command == 'exit') {
          _emit('Session closing...\r\n');
          await disconnect();
          return;
        }

        _emit('echo: $command\r\n');
        continue;
      }

      if (rune < 32) {
        continue;
      }

      final char = String.fromCharCode(rune);
      _inputBuffer.write(char);
      _emit(char);
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_outputController.isClosed) {
      _emit('Disconnected.\r\n');
      await _outputController.close();
    }
  }

  @override
  Future<void> resizeTerminal(
    int width,
    int height, {
    int pixelWidth = 0,
    int pixelHeight = 0,
  }) async {}

  void _emit(String line) {
    if (!_outputController.isClosed) {
      _outputController.add(line);
    }
  }
}
