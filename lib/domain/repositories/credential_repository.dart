import 'package:small_ssh/domain/models/credential_ref.dart';

abstract class CredentialRepository {
  Future<String?> readSecret(CredentialRef credentialRef);
  Future<void> writeSecret(CredentialRef credentialRef, String secret);
}
