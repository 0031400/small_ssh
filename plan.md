# small_ssh Architecture Plan

## 1. Goals and Scope
- Build a Flutter Windows SSH client with good baseline usability first, then add advanced capabilities.
- Prioritize secure credential handling, stable terminal sessions, and clean extensibility.
- Start with MVP: connect, authenticate, run interactive shell, save host profiles.

## 2. Architecture Style
Use layered architecture with clear boundaries:
- `presentation`: Flutter UI (pages, widgets, keyboard shortcuts, theme).
- `application`: use-cases and orchestration (connect/disconnect/reconnect, run command, transfer file).
- `domain`: core models and business rules (HostProfile, Session, CredentialRef, TransferTask).
- `infrastructure`: SSH implementation, local storage, secure storage, logging, platform integrations.

Dependency rule:
- `presentation -> application -> domain`
- `infrastructure -> domain/application interfaces`
- `domain` must not depend on Flutter/framework details.

## 3. Feature Modules
### 3.1 Connection Manager
Responsibilities:
- Create/manage multiple SSH sessions.
- Maintain explicit connection state machine:
  - `idle`
  - `connecting`
  - `connected`
  - `reconnecting`
  - `disconnected`
  - `error`
- Reconnect with backoff policy.
- Surface structured errors for UI.

### 3.2 Terminal Engine
Responsibilities:
- Bind SSH shell channel to terminal widget (`xterm` recommended).
- Handle ANSI sequences and resize events.
- Buffer output safely to avoid UI jank.
- Normalize keyboard mappings for Windows terminal behavior.

### 3.3 Host Profile Repository
Responsibilities:
- CRUD for host profiles (name, host, port, user, tags, options).
- Keep non-sensitive config in local database (`Isar`/`Hive`).
- Store references to secrets, not plain secrets in DB.

### 3.4 Credential Vault
Responsibilities:
- Manage passwords/passphrases/private key material via secure storage.
- Support auth types:
  - password
  - private key file
  - private key text
- Never persist plaintext password in normal local DB.

### 3.5 SFTP Service (phase 2)
Responsibilities:
- Remote directory listing and metadata.
- Upload/download with progress and cancellation.
- Queue tasks and limit parallelism.

### 3.6 Logging and Diagnostics
Responsibilities:
- Structured logs with level filtering.
- Redact secrets before persistence/export.
- Connection diagnostics export for troubleshooting.

## 4. State Management and Data Flow
Recommended stack:
- `Riverpod` for state management and dependency injection.
- Immutable state models for session and transfer progress.
- Separate short-lived runtime state (sessions) from persisted state (profiles/preferences).

Flow example:
1. UI dispatches `ConnectToHost` use-case.
2. Use-case resolves credential from vault and host from repository.
3. Infrastructure SSH client opens connection/channel.
4. Session state stream updates UI (`connecting -> connected`).
5. Terminal engine streams bytes both ways.

## 5. Security Plan
- Enforce host key verification (`known_hosts`-style trust model).
- Show host fingerprint on first connect with explicit trust confirmation.
- Keep secrets in secure storage only.
- Redact command history option for sensitive environments.
- Add session auto-lock/timeout option later.

## 6. Error Handling Strategy
- Define typed failures (AuthFailure, NetworkFailure, HostKeyMismatch, TimeoutFailure).
- Map low-level SSH exceptions into domain/app failures.
- Show actionable user messages and retry actions.

## 7. Proposed Project Structure
```text
lib/
  app/
    app.dart
    router.dart
    theme.dart
  presentation/
    pages/
      home_page.dart
      session_page.dart
      hosts_page.dart
      settings_page.dart
    widgets/
      terminal_view.dart
      host_form.dart
  application/
    usecases/
      connect_to_host.dart
      disconnect_session.dart
      execute_command.dart
    services/
      session_orchestrator.dart
  domain/
    models/
      host_profile.dart
      ssh_session.dart
      credential_ref.dart
      transfer_task.dart
    repositories/
      host_profile_repository.dart
      credential_repository.dart
    failures/
      app_failure.dart
  infrastructure/
    ssh/
      dartssh2_client.dart
    persistence/
      isar_host_profile_repository.dart
    security/
      secure_storage_credential_repository.dart
    logging/
      logger.dart
```

## 8. Milestones
### Milestone 0 (MVP)
- Single session SSH terminal.
- Host profile save/load.
- Password authentication.
- Basic connection error feedback.

### Milestone 1
- Multi-tab sessions.
- Private key authentication.
- Host key verification and trust store.
- Reconnect strategy.

### Milestone 2
- SFTP browser and transfer queue.
- Progress/cancel/retry UI.
- Basic transfer conflict handling.

### Milestone 3
- Jump host/proxy support.
- Port forwarding.
- Snippets/quick commands.
- Session analytics and richer diagnostics.

## 9. Testing Strategy
- Unit tests:
  - Use-cases
  - Connection state transitions
  - Failure mapping
- Widget tests:
  - Session state rendering
  - Host form validation
- Integration tests:
  - SSH mock server flows (connect/auth/fail/reconnect)

## 10. Immediate Next Actions
1. Create domain models and repository interfaces first.
2. Implement `dartssh2` adapter behind an interface.
3. Build a minimal terminal page wired to one live session.
4. Add secure credential storage before adding more auth modes.
