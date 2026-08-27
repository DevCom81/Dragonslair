import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedAppLocales = [
  Locale('fr'),
  Locale('en'),
  Locale('es'),
  Locale('de'),
];

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

class LocaleController extends Notifier<Locale> {
  static const _prefsKey = 'app_locale';

  @override
  Locale build() => const Locale('fr');

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == null) {
        return;
      }
      final match = supportedAppLocales.where((locale) {
        return locale.languageCode == code;
      });
      if (match.isNotEmpty) {
        state = match.first;
      }
    } on Exception {
      // Keep the default French locale if storage is unavailable.
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } on Exception {
      // Locale still applies for this session.
    }
  }
}
