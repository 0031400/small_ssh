import 'dart:async';

import 'package:small_ssh/domain/models/auth_method.dart';

class SshConnectRequest {
  const SshConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
    this.authMethod = AuthMethod.password,
    this.keyboardInteractivePassword,
  });

  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? privateKeyPassphrase;
  final AuthMethod authMethod;
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
  Future<void> disconnect();
}

abstract class SshGateway {
  Future<SshConnection> connect(SshConnectRequest request);
}
