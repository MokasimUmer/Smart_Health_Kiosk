import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

class LanguageService extends ChangeNotifier {
  static const _key = 'app_language';

  /// Global instance — set once in main(), read anywhere.
  static late LanguageService instance;

  AppStrings _strings = AppStrings.en;
  AppStrings get strings => _strings;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    _strings = AppStrings.fromCode(code);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _strings = AppStrings.fromCode(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    notifyListeners();
  }

  String get currentCode => _strings.languageCode;
}
