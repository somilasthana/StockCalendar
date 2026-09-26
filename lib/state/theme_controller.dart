import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs);

  final SharedPreferences _prefs;
  ThemeMode mode = ThemeMode.dark;

  void load() {
    final dark = _prefs.getBool('dark_theme') ?? true;
    mode = dark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> setDark(bool dark) async {
    mode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool('dark_theme', dark);
    notifyListeners();
  }
}
