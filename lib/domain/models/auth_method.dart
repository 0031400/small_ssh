enum AuthMethod { password, privateKey, keyboardInteractive }

enum AuthOrderMode { global, host }

const List<AuthMethod> defaultAuthOrder = [
  AuthMethod.password,
  AuthMethod.privateKey,
  AuthMethod.keyboardInteractive,
];

String authMethodLabel(AuthMethod method) {
  switch (method) {
    case AuthMethod.password:
      return 'Password';
    case AuthMethod.privateKey:
      return 'Private Key';
    case AuthMethod.keyboardInteractive:
      return 'Keyboard Interactive';
  }
}
