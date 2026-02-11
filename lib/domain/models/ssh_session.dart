import 'package:small_ssh/domain/models/connection_state_status.dart';

class SshSession {
  const SshSession({
    required this.id,
    required this.hostProfileId,
    required this.status,
    required this.createdAt,
    this.lastError,
  });

  final String id;
  final String hostProfileId;
  final ConnectionStateStatus status;
  final DateTime createdAt;
  final String? lastError;

  SshSession copyWith({ConnectionStateStatus? status, String? lastError}) {
    return SshSession(
      id: id,
      hostProfileId: hostProfileId,
      status: status ?? this.status,
      createdAt: createdAt,
      lastError: lastError,
    );
  }
}
