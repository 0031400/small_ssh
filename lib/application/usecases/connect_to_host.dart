class ConnectToHostInput {
  const ConnectToHostInput({required this.hostId});

  final String hostId;
}

class ConnectToHostUseCase {
  ConnectToHostInput buildInput(String hostId) {
    return ConnectToHostInput(hostId: hostId);
  }
}
