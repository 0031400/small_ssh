class DisconnectSessionInput {
  const DisconnectSessionInput({required this.sessionId});

  final String sessionId;
}

class DisconnectSessionUseCase {
  DisconnectSessionInput buildInput(String sessionId) {
    return DisconnectSessionInput(sessionId: sessionId);
  }
}
