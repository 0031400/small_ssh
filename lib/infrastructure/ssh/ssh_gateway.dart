import 'dart:async';

import 'package:small_ssh/domain/models/sftp_entry.dart';

class KeyboardInteractivePrompt {
  const KeyboardInteractivePrompt({
    required this.promptText,
    required this.echo,
  });

  final String promptText;
  final bool echo;
}

class KeyboardInteractiveRequest {
  const KeyboardInteractiveRequest({
    required this.name,
    required this.instruction,
    required this.prompts,
  });

  final String name;
  final String instruction;
  final List<KeyboardInteractivePrompt> prompts;
}

typedef KeyboardInteractiveHandler =
    Future<List<String>?> Function(KeyboardInteractiveRequest request);

class SshConnectRequest {
  const SshConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
    this.keyboardInteractivePassword,
    this.onKeyboardInteractive,
  });

  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? privateKeyPassphrase;
  final String? keyboardInteractivePassword;
  final KeyboardInteractiveHandler? onKeyboardInteractive;
}

abstract class SshConnection {
  String get id;
  Stream<String> get output;
  Future<void> sendInput(String input);
  Future<void> resizeTerminal(
    int width,
    int height, {
    int pixelWidth = 0,
    int pixelHeight = 0,
  });
  Future<String> resolveSftpHome();
  Future<List<SftpEntry>> listSftpDirectory(String path);
  Future<void> createSftpDirectory(String path);
  Future<void> deleteSftpEntry({
    required String path,
    required bool isDirectory,
  });
  Future<void> downloadSftpFile({
    required String remotePath,
    required String localPath,
    void Function(int transferred, int total)? onProgress,
    bool Function()? shouldCancel,
  });
  Future<void> uploadSftpFile({
    required String localPath,
    required String remotePath,
    void Function(int transferred, int total)? onProgress,
    bool Function()? shouldCancel,
  });
  Future<void> disconnect();
}

abstract class SshGateway {
  Future<SshConnection> connect(SshConnectRequest request);
}
