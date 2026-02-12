import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:small_ssh/domain/models/auth_method.dart';

enum ClipboardBehavior {
  contextMenu,
  direct,
}

class AppSettings extends ChangeNotifier {
  static const _fileName = 'small_ssh_settings.json';

  ThemeMode _themeMode = ThemeMode.system;
  double _terminalFontSize = 13;
  ClipboardBehavior _clipboardBehavior = ClipboardBehavior.contextMenu;
  List<AuthMethod> _authOrder = List<AuthMethod>.of(defaultAuthOrder);
  bool _loading = false;

  ThemeMode get themeMode => _themeMode;
  double get terminalFontSize => _terminalFontSize;
  ClipboardBehavior get clipboardBehavior => _clipboardBehavior;
  List<AuthMethod> get authOrder => List<AuthMethod>.unmodifiable(_authOrder);

  Future<void> load() async {
    if (kIsWeb) {
      return;
    }
    _loading = true;
    try {
      final file = File(_settingsPath());
      if (!await file.exists()) {
        return;
      }
      final content = await file.readAsString();
      final data = jsonDecode(content);
      if (data is! Map<String, dynamic>) {
        return;
      }
      _themeMode = _parseThemeMode(data['themeMode']) ?? _themeMode;
      _terminalFontSize =
          _parseDouble(data['terminalFontSize']) ?? _terminalFontSize;
      _clipboardBehavior =
          _parseClipboardBehavior(data['clipboardBehavior']) ??
              _clipboardBehavior;
      _authOrder = _parseAuthOrder(data['authOrder']) ?? _authOrder;
      notifyListeners();
    } catch (_) {
      // Ignore corrupted settings and keep defaults.
    } finally {
      _loading = false;
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    _save();
  }

  void setTerminalFontSize(double value) {
    final clamped = value.clamp(10, 22).toDouble();
    if (_terminalFontSize == clamped) {
      return;
    }
    _terminalFontSize = clamped;
    notifyListeners();
    _save();
  }

  void setClipboardBehavior(ClipboardBehavior behavior) {
    if (_clipboardBehavior == behavior) {
      return;
    }
    _clipboardBehavior = behavior;
    notifyListeners();
    _save();
  }

  void setAuthOrder(List<AuthMethod> order) {
    if (_listEquals(_authOrder, order)) {
      return;
    }
    _authOrder = List<AuthMethod>.of(order);
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    if (_loading || kIsWeb) {
      return;
    }
    try {
      final file = File(_settingsPath());
      final data = <String, dynamic>{
        'themeMode': _themeMode.name,
        'terminalFontSize': _terminalFontSize,
        'clipboardBehavior': _clipboardBehavior.name,
        'authOrder': _authOrder.map((item) => item.name).toList(),
      };
      await file.writeAsString(jsonEncode(data));
    } catch (_) {
      // Ignore write failures (read-only directory, etc).
    }
  }

  String _settingsPath() {
    final exePath = Platform.resolvedExecutable;
    final dir = File(exePath).parent.path;
    return '$dir${Platform.pathSeparator}$_fileName';
  }

  ThemeMode? _parseThemeMode(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return null;
  }

  ClipboardBehavior? _parseClipboardBehavior(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final behavior in ClipboardBehavior.values) {
      if (behavior.name == value) {
        return behavior;
      }
    }
    return null;
  }

  List<AuthMethod>? _parseAuthOrder(Object? value) {
    if (value is List) {
      final parsed = <AuthMethod>[];
      for (final item in value) {
        final name = item.toString();
        for (final method in AuthMethod.values) {
          if (method.name == name && !parsed.contains(method)) {
            parsed.add(method);
          }
        }
      }
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return null;
  }

  bool _listEquals(List<AuthMethod> a, List<AuthMethod> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
