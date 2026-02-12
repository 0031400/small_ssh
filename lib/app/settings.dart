import 'package:flutter/material.dart';

enum ClipboardBehavior {
  contextMenu,
  direct,
}

class AppSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  double _terminalFontSize = 13;
  ClipboardBehavior _clipboardBehavior = ClipboardBehavior.contextMenu;

  ThemeMode get themeMode => _themeMode;
  double get terminalFontSize => _terminalFontSize;
  ClipboardBehavior get clipboardBehavior => _clipboardBehavior;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
  }

  void setTerminalFontSize(double value) {
    final clamped = value.clamp(10, 22).toDouble();
    if (_terminalFontSize == clamped) {
      return;
    }
    _terminalFontSize = clamped;
    notifyListeners();
  }

  void setClipboardBehavior(ClipboardBehavior behavior) {
    if (_clipboardBehavior == behavior) {
      return;
    }
    _clipboardBehavior = behavior;
    notifyListeners();
  }
}
