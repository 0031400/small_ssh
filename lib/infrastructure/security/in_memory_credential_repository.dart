import 'package:small_ssh/domain/models/credential_ref.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';

class InMemoryCredentialRepository implements CredentialRepository {
  final Map<String, String> _secrets = <String, String>{
    'local-dev-password': 'devpass',
    'demo-box-password': 'toor',
  };

  @override
  Future<String?> readSecret(CredentialRef credentialRef) async {
    return _secrets[credentialRef.id];
  }

  @override
  Future<void> writeSecret(CredentialRef credentialRef, String secret) async {
    final trimmed = secret.trim();
    if (trimmed.isEmpty) {
      _secrets.remove(credentialRef.id);
      return;
    }
    _secrets[credentialRef.id] = secret;
  }
}
