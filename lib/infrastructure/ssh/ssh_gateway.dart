import 'dart:async';

import 'package:small_ssh/domain/models/sftp_entry.dart';

class SshConnectRequest {
  const SshConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
    this.keyboardInteractivePassword,
  });

  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? privateKeyPassphrase;
  final String? keyboardInteractivePassword;
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
