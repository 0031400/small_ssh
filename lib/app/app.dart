import 'package:flutter/material.dart';
import 'package:small_ssh/app/settings.dart';
import 'package:small_ssh/app/theme.dart';
import 'package:small_ssh/application/services/session_orchestrator.dart';
import 'package:small_ssh/application/usecases/connect_to_host.dart';
import 'package:small_ssh/application/usecases/disconnect_session.dart';
import 'package:small_ssh/domain/repositories/credential_repository.dart';
import 'package:small_ssh/domain/repositories/host_profile_repository.dart';
import 'package:small_ssh/infrastructure/persistence/file_host_profile_repository.dart';
import 'package:small_ssh/infrastructure/security/file_credential_repository.dart';
import 'package:small_ssh/infrastructure/ssh/dartssh2_gateway.dart';
import 'package:small_ssh/presentation/pages/home_page.dart';

class SmallSshApp extends StatefulWidget {
  const SmallSshApp({super.key});

  @override
  State<SmallSshApp> createState() => _SmallSshAppState();
}

class _SmallSshAppState extends State<SmallSshApp> {
  late final HostProfileRepository _hostRepository;
  late final CredentialRepository _credentialRepository;
  late final SessionOrchestrator _orchestrator;
  late final AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _hostRepository = FileHostProfileRepository();
    _credentialRepository = FileCredentialRepository();
    _settings = AppSettings();
    _settings.load();

    _orchestrator = SessionOrchestrator(
      hostRepository: _hostRepository,
      credentialRepository: _credentialRepository,
      sshGateway: DartSsh2Gateway(),
      connectToHostUseCase: ConnectToHostUseCase(),
      disconnectSessionUseCase: DisconnectSessionUseCase(),
    );

    _orchestrator.initialize();
  }

  @override
  void dispose() {
    _orchestrator.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'small_ssh',
          theme: buildAppTheme(),
          darkTheme: buildAppDarkTheme(),
          themeMode: _settings.themeMode,
          home: HomePage(
            orchestrator: _orchestrator,
            settings: _settings,
            credentialRepository: _credentialRepository,
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
