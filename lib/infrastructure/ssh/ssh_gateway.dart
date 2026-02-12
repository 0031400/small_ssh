import 'dart:async';

class SshConnectRequest {
  const SshConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
    this.privateKeyPassphrase,
  });

  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? privateKeyPassphrase;
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
