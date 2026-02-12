enum PrivateKeyMode { global, host, none }

class HostProfile {
  const HostProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.privateKeyMode = PrivateKeyMode.global,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final PrivateKeyMode privateKeyMode;
}
