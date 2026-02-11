enum CredentialKind { password, privateKeyFile, privateKeyText }

class CredentialRef {
  const CredentialRef({required this.id, required this.kind});

  final String id;
  final CredentialKind kind;
}
