import 'dart:async';

import 'package:small_ssh/domain/models/sftp_entry.dart';
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

  @override
  Future<String> resolveSftpHome() async {
    return '/';
  }

  @override
  Future<List<SftpEntry>> listSftpDirectory(String path) async {
    return <SftpEntry>[
      SftpEntry(name: 'mock.txt', path: '/mock.txt', isDirectory: false),
      SftpEntry(name: 'demo', path: '/demo', isDirectory: true),
    ];
  }

  @override
  Future<void> createSftpDirectory(String path) async {
    throw UnsupportedError('Mock SFTP create directory not implemented');
  }

  @override
  Future<void> deleteSftpEntry({
    required String path,
    required bool isDirectory,
  }) async {
    throw UnsupportedError('Mock SFTP delete not implemented');
  }

  @override
  Future<void> downloadSftpFile({
    required String remotePath,
    required String localPath,
    void Function(int transferred, int total)? onProgress,
  }) async {
    throw UnsupportedError('Mock SFTP download not implemented');
  }

  @override
  Future<void> uploadSftpFile({
    required String localPath,
    required String remotePath,
    void Function(int transferred, int total)? onProgress,
  }) async {
    throw UnsupportedError('Mock SFTP upload not implemented');
  }

  void _emit(String line) {
    if (!_outputController.isClosed) {
      _outputController.add(line);
    }
  }
}
