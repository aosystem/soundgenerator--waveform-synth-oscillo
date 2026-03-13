import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundgenerator/l10n/app_localizations.dart';

class Model {
  Model._();

  static const String _prefSchemeColor = 'schemeColor';
  static const String _prefThemeNumber = 'themeNumber';
  static const String _prefLanguageCode = 'languageCode';

  static bool _ready = false;
  static int _schemeColor = 0;
  static int _themeNumber = 0;
  static String _languageCode = '';

  static int get schemeColor => _schemeColor;
  static int get themeNumber => _themeNumber;
  static String get languageCode => _languageCode;

  static Future<void> ensureReady() async {
    if (_ready) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    //
    _schemeColor = (prefs.getInt(_prefSchemeColor) ?? 0).clamp(0, 360);
    _themeNumber = (prefs.getInt(_prefThemeNumber) ?? 0).clamp(0, 2);
    _languageCode = prefs.getString(_prefLanguageCode) ?? ui.PlatformDispatcher.instance.locale.languageCode;
    _languageCode = _resolveLanguageCode(_languageCode);
    _ready = true;
  }

  static String _resolveLanguageCode(String code) {
    final supported = AppLocalizations.supportedLocales;
    if (supported.any((l) => l.languageCode == code)) {
      return code;
    } else {
      return '';
    }
  }

  static Future<void> setSchemeColor(int value) async {
    _schemeColor = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefSchemeColor, value);
  }

  static Future<void> setThemeNumber(int value) async {
    _themeNumber = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefThemeNumber, value);
  }

  static Future<void> setLanguageCode(String value) async {
    _languageCode = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefLanguageCode, value);
  }

}
