import 'dart:async';

class SshConnectRequest {
  const SshConnectRequest({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String username;
  final String password;
}

abstract class SshConnection {
  String get id;
  Stream<String> get output;
  Future<void> sendInput(String input);
  Future<void> disconnect();
}

abstract class SshGateway {
  Future<SshConnection> connect(SshConnectRequest request);
}
