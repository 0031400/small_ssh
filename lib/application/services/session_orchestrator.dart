import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:small_ssh/application/usecases/connect_to_host.dart';
import 'package:small_ssh/application/usecases/disconnect_session.dart';
import 'package:small_ssh/domain/models/auth_method.dart';
import 'package:small_ssh/domain/models/connection_state_status.dart';
import 'package:small_ssh/domain/models/credential_ref.dart';
import 'package:small_ssh/domain/models/host_profile.dart';
import 'package:small_ssh/domain/models/ssh_session.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';
import 'package:small_ssh/domain/repositories/host_profile_repository.dart';
import 'package:small_ssh/infrastructure/ssh/ssh_gateway.dart';

class SessionView {
  const SessionView({
    required this.session,
    required this.hostProfile,
    required this.output,
  });

  final SshSession session;
  final HostProfile hostProfile;
  final List<String> output;
}

class SessionOrchestrator extends ChangeNotifier {
  SessionOrchestrator({
    required HostProfileRepository hostRepository,
    required CredentialRepository credentialRepository,
    required SshGateway sshGateway,
    required ConnectToHostUseCase connectToHostUseCase,
    required DisconnectSessionUseCase disconnectSessionUseCase,
  }) : _hostRepository = hostRepository,
       _credentialRepository = credentialRepository,
       _sshGateway = sshGateway,
       _connectToHostUseCase = connectToHostUseCase,
       _disconnectSessionUseCase = disconnectSessionUseCase;

  final HostProfileRepository _hostRepository;
  final CredentialRepository _credentialRepository;
  final SshGateway _sshGateway;
  final ConnectToHostUseCase _connectToHostUseCase;
  final DisconnectSessionUseCase _disconnectSessionUseCase;

  final List<HostProfile> _hosts = <HostProfile>[];
  final Map<String, _ManagedSession> _sessions = <String, _ManagedSession>{};

  String? _activeSessionId;
  bool _loadingHosts = true;

  List<HostProfile> get hosts => List<HostProfile>.unmodifiable(_hosts);

  List<SessionView> get sessions {
    return _sessions.values
        .map(
          (managed) => SessionView(
            session: managed.session,
            hostProfile: managed.hostProfile,
            output: List<String>.unmodifiable(managed.output),
          ),
        )
        .toList(growable: false);
  }

  String? get activeSessionId => _activeSessionId;
  bool get loadingHosts => _loadingHosts;

  SessionView? get activeSession {
    final id = _activeSessionId;
    if (id == null) {
      return null;
    }

    final managed = _sessions[id];
    if (managed == null) {
      return null;
    }

    return SessionView(
      session: managed.session,
      hostProfile: managed.hostProfile,
      output: List<String>.unmodifiable(managed.output),
    );
  }

  Future<void> initialize() async {
    _loadingHosts = true;
    notifyListeners();

    final loadedHosts = await _hostRepository.getAll();
    _hosts
      ..clear()
      ..addAll(loadedHosts);

    _loadingHosts = false;
    notifyListeners();
  }

  Future<bool> hasPasswordForHost(String hostId) async {
    final credential = CredentialRef(
      id: '$hostId-password',
      kind: CredentialKind.password,
    );
    final secret = await _credentialRepository.readSecret(credential);
    return secret != null && secret.trim().isNotEmpty;
  }

  Future<bool> needsPasswordForHost(
    String hostId, {
    List<AuthMethod>? authOrder,
  }) async {
    final host = await _hostRepository.findById(hostId);
    if (host == null) {
      return false;
    }

    final keyMaterial = await _loadPrivateKeyForHost(host);
    final order = _normalizeAuthOrder(authOrder ?? host.authOrder);
    if (order.contains(AuthMethod.privateKey) && keyMaterial != null) {
      return false;
    }

    final needsPassword =
        order.contains(AuthMethod.password) ||
        order.contains(AuthMethod.keyboardInteractive);
    if (!needsPassword) {
      return false;
    }

    final credential = CredentialRef(
      id: '$hostId-password',
      kind: CredentialKind.password,
    );
    final secret = await _credentialRepository.readSecret(credential);
    return secret == null || secret.trim().isEmpty;
  }

  Future<void> connectToHost(
    String hostId, {
    String? passwordOverride,
    List<AuthMethod>? authOrder,
  }) async {
    final input = _connectToHostUseCase.buildInput(hostId);
    final host = await _hostRepository.findById(input.hostId);

    if (host == null) {
      return;
    }

    final pendingSession = SshSession(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      hostProfileId: host.id,
      status: ConnectionStateStatus.connecting,
      createdAt: DateTime.now(),
    );

    final pendingManaged = _ManagedSession(
      hostProfile: host,
      session: pendingSession,
      output: <String>['Connecting to ${host.host}:${host.port}...\r\n'],
    );

    _sessions[pendingSession.id] = pendingManaged;
    _activeSessionId = pendingSession.id;
    notifyListeners();

    try {
      final keyMaterial = await _loadPrivateKeyForHost(host);
      final credential = CredentialRef(
        id: '${host.id}-password',
        kind: CredentialKind.password,
      );
      final storedPassword = await _credentialRepository.readSecret(credential);
      final override = passwordOverride?.trim();
      final password =
          (override != null && override.isNotEmpty)
              ? override
              : storedPassword?.trim();
      final hasPassword = password != null && password.isNotEmpty;
      final order = _normalizeAuthOrder(authOrder ?? host.authOrder);
      final connection = await _connectWithAuthOrder(
        host: host,
        authOrder: order,
        password: hasPassword ? password : null,
        privateKey: keyMaterial?.privateKey,
        privateKeyPassphrase: keyMaterial?.passphrase,
        pending: pendingManaged,
      );

      if ((storedPassword == null || storedPassword.trim().isEmpty) &&
          override != null &&
          override.isNotEmpty) {
        await _credentialRepository.writeSecret(credential, override);
      }

      final connectedSession = SshSession(
        id: connection.id,
        hostProfileId: host.id,
        status: ConnectionStateStatus.connected,
        createdAt: pendingSession.createdAt,
      );

      final managed = _ManagedSession(
        hostProfile: host,
        session: connectedSession,
        connection: connection,
        output: List<String>.from(pendingManaged.output),
      );

      managed.subscription = connection.output.listen(
        (line) {
          managed.output.add(line);
          notifyListeners();
        },
        onDone: () {
          managed.session = managed.session.copyWith(
            status: ConnectionStateStatus.disconnected,
          );
          notifyListeners();
        },
      );

      _sessions
        ..remove(pendingSession.id)
        ..[connectedSession.id] = managed;

      _activeSessionId = connectedSession.id;
      notifyListeners();
    } catch (error) {
      pendingManaged.session = pendingManaged.session.copyWith(
        status: ConnectionStateStatus.error,
        lastError: error.toString(),
      );
      pendingManaged.output.add('Connection failed: $error\r\n');
      notifyListeners();
    }
  }

  Future<String?> addHostProfile({
    required String name,
    required String host,
    required int port,
    required String username,
    String? password,
    required PrivateKeyMode privateKeyMode,
    String? privateKey,
    String? privateKeyPassphrase,
    required AuthOrderMode authOrderMode,
    required List<AuthMethod> authOrder,
  }) async {
    final normalizedName = name.trim();
    final normalizedHost = host.trim();
    final normalizedUser = username.trim();

    if (normalizedName.isEmpty ||
        normalizedHost.isEmpty ||
        normalizedUser.isEmpty) {
      return 'Name, host and username are required.';
    }

    if (port <= 0 || port > 65535) {
      return 'Port must be between 1 and 65535.';
    }

    final profile = HostProfile(
      id: 'host-${DateTime.now().microsecondsSinceEpoch}',
      name: normalizedName,
      host: normalizedHost,
      port: port,
      username: normalizedUser,
      privateKeyMode: privateKeyMode,
      authOrderMode: authOrderMode,
      authOrder: _normalizeAuthOrder(authOrder),
    );

    await _hostRepository.save(profile);
    final secret = password?.trim();
    if (secret != null && secret.isNotEmpty) {
      await _credentialRepository.writeSecret(
        CredentialRef(
          id: '${profile.id}-password',
          kind: CredentialKind.password,
        ),
        secret,
      );
    }
    await _writePrivateKeyIfNeeded(
      hostId: profile.id,
      mode: privateKeyMode,
      privateKey: privateKey,
      passphrase: privateKeyPassphrase,
    );
    _hosts.add(profile);
    notifyListeners();
    return null;
  }

  Future<String?> updateHostProfile({
    required String hostId,
    required String name,
    required String host,
    required int port,
    required String username,
    String? password,
    required PrivateKeyMode privateKeyMode,
    String? privateKey,
    String? privateKeyPassphrase,
    required AuthOrderMode authOrderMode,
    required List<AuthMethod> authOrder,
  }) async {
    final normalizedName = name.trim();
    final normalizedHost = host.trim();
    final normalizedUser = username.trim();

    if (normalizedName.isEmpty ||
        normalizedHost.isEmpty ||
        normalizedUser.isEmpty) {
      return 'Name, host and username are required.';
    }

    if (port <= 0 || port > 65535) {
      return 'Port must be between 1 and 65535.';
    }

    final hostIndex = _hosts.indexWhere((item) => item.id == hostId);
    if (hostIndex < 0) {
      return 'Host not found.';
    }

    final updated = HostProfile(
      id: hostId,
      name: normalizedName,
      host: normalizedHost,
      port: port,
      username: normalizedUser,
      privateKeyMode: privateKeyMode,
      authOrderMode: authOrderMode,
      authOrder: _normalizeAuthOrder(authOrder),
    );

    await _hostRepository.save(updated);
    _hosts[hostIndex] = updated;

    final secret = password?.trim();
    if (secret != null && secret.isNotEmpty) {
      await _credentialRepository.writeSecret(
        CredentialRef(id: '$hostId-password', kind: CredentialKind.password),
        secret,
      );
    }
    await _writePrivateKeyIfNeeded(
      hostId: hostId,
      mode: privateKeyMode,
      privateKey: privateKey,
      passphrase: privateKeyPassphrase,
    );

    for (final managed in _sessions.values) {
      if (managed.hostProfile.id == hostId) {
        managed.hostProfile = updated;
      }
    }

    notifyListeners();
    return null;
  }

  Future<void> removeHostProfile(String hostId) async {
    await _hostRepository.deleteById(hostId);
    _hosts.removeWhere((host) => host.id == hostId);

    final sessionIds = _sessions.entries
        .where((entry) => entry.value.hostProfile.id == hostId)
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final sessionId in sessionIds) {
      await removeSession(sessionId);
    }

    notifyListeners();
  }

  Future<void> disconnectSession(String sessionId) async {
    final input = _disconnectSessionUseCase.buildInput(sessionId);
    final managed = _sessions[input.sessionId];
    if (managed == null) {
      return;
    }

    await managed.connection?.disconnect();
    await managed.subscription?.cancel();

    managed.session = managed.session.copyWith(
      status: ConnectionStateStatus.disconnected,
    );

    if (_activeSessionId == input.sessionId) {
      _activeSessionId = _nextActiveSessionId(excluding: input.sessionId);
    }

    notifyListeners();
  }

  Future<void> removeSession(String sessionId) async {
    final managed = _sessions.remove(sessionId);
    if (managed == null) {
      return;
    }

    await managed.connection?.disconnect();
    await managed.subscription?.cancel();

    if (_activeSessionId == sessionId) {
      _activeSessionId = _nextActiveSessionId(excluding: sessionId);
    }

    notifyListeners();
  }

  Future<void> sendInput(String sessionId, String input) async {
    final managed = _sessions[sessionId];
    if (managed == null || managed.connection == null) {
      return;
    }

    await managed.connection!.sendInput(input);
  }

  Future<void> resizeTerminal(
    String sessionId,
    int width,
    int height, {
    int pixelWidth = 0,
    int pixelHeight = 0,
  }) async {
    final managed = _sessions[sessionId];
    if (managed == null || managed.connection == null) {
      return;
    }

    await managed.connection!.resizeTerminal(
      width,
      height,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
    );
  }

  void setActiveSession(String sessionId) {
    if (_sessions.containsKey(sessionId)) {
      _activeSessionId = sessionId;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final managed in _sessions.values) {
      managed.subscription?.cancel();
      managed.connection?.disconnect();
    }
    super.dispose();
  }

  String? _nextActiveSessionId({required String excluding}) {
    for (final id in _sessions.keys) {
      if (id != excluding) {
        return id;
      }
    }
    return null;
  }

  Future<_PrivateKeyMaterial?> _loadPrivateKeyForHost(HostProfile host) async {
    final mode = host.privateKeyMode;
    if (mode == PrivateKeyMode.none) {
      return null;
    }

    final keyId = mode == PrivateKeyMode.host
        ? '${host.id}-private-key'
        : 'global-private-key';
    final passphraseId = mode == PrivateKeyMode.host
        ? '${host.id}-private-key-passphrase'
        : 'global-private-key-passphrase';

    final key = await _credentialRepository.readSecret(
      CredentialRef(id: keyId, kind: CredentialKind.privateKeyText),
    );
    if (key == null || key.trim().isEmpty) {
      return null;
    }
    final passphrase = await _credentialRepository.readSecret(
      CredentialRef(id: passphraseId, kind: CredentialKind.privateKeyPassphrase),
    );
    return _PrivateKeyMaterial(
      privateKey: key,
      passphrase: passphrase?.trim().isEmpty == true ? null : passphrase,
    );
  }

  Future<void> _writePrivateKeyIfNeeded({
    required String hostId,
    required PrivateKeyMode mode,
    String? privateKey,
    String? passphrase,
  }) async {
    if (mode != PrivateKeyMode.host) {
      return;
    }
    final key = privateKey?.trim();
    if (key != null && key.isNotEmpty) {
      await _credentialRepository.writeSecret(
        CredentialRef(
          id: '$hostId-private-key',
          kind: CredentialKind.privateKeyText,
        ),
        privateKey!,
      );
    }
    final pass = passphrase?.trim();
    if (pass != null && pass.isNotEmpty) {
      await _credentialRepository.writeSecret(
        CredentialRef(
          id: '$hostId-private-key-passphrase',
          kind: CredentialKind.privateKeyPassphrase,
        ),
        passphrase!,
      );
    }
  }

  List<AuthMethod> _normalizeAuthOrder(List<AuthMethod> order) {
    final normalized = <AuthMethod>[];
    for (final method in order) {
      if (!normalized.contains(method)) {
        normalized.add(method);
      }
    }
    if (normalized.isEmpty) {
      return List<AuthMethod>.of(defaultAuthOrder);
    }
    return normalized;
  }

  Future<SshConnection> _connectWithAuthOrder({
    required HostProfile host,
    required List<AuthMethod> authOrder,
    required _ManagedSession pending,
    String? password,
    String? privateKey,
    String? privateKeyPassphrase,
  }) async {
    if (authOrder.isEmpty) {
      throw StateError('No authentication methods configured.');
    }

    Object? lastError;
    var attempted = false;
    for (final method in authOrder) {
      final label = authMethodLabel(method);
      if (method == AuthMethod.privateKey &&
          (privateKey == null || privateKey.trim().isEmpty)) {
        pending.output.add('Skipping $label (no private key).\r\n');
        continue;
      }
      if ((method == AuthMethod.password ||
              method == AuthMethod.keyboardInteractive) &&
          (password == null || password.trim().isEmpty)) {
        pending.output.add('Skipping $label (no password).\r\n');
        continue;
      }

      pending.output.add('Trying $label authentication...\r\n');
      notifyListeners();
      attempted = true;
      try {
        final request = SshConnectRequest(
          host: host.host,
          port: host.port,
          username: host.username,
          authMethod: method,
          password: method == AuthMethod.password ? password : null,
          privateKey: method == AuthMethod.privateKey ? privateKey : null,
          privateKeyPassphrase:
              method == AuthMethod.privateKey ? privateKeyPassphrase : null,
          keyboardInteractivePassword:
              method == AuthMethod.keyboardInteractive ? password : null,
        );
        return await _sshGateway.connect(request);
      } catch (error) {
        lastError = error;
        pending.output.add('Auth failed ($label): $error\r\n');
        notifyListeners();
      }
    }
    if (!attempted) {
      throw StateError('No authentication methods available.');
    }
    throw lastError ?? StateError('Authentication failed.');
  }
}

class _PrivateKeyMaterial {
  const _PrivateKeyMaterial({required this.privateKey, this.passphrase});

  final String privateKey;
  final String? passphrase;
}

class _ManagedSession {
  _ManagedSession({
    required this.hostProfile,
    required this.session,
    this.connection,
    required this.output,
  });

  HostProfile hostProfile;
  SshSession session;
  final SshConnection? connection;
  final List<String> output;
  StreamSubscription<String>? subscription;
}
