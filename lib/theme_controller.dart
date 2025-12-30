import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  // Holds the current ThemeMode; default to light.
  final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(ThemeMode.light);

  void set(ThemeMode m) => mode.value = m;
  void toggle() => mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

