import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'app_locale';

/// Persisted UI language (English/Arabic) — defaults to the device locale
/// when it's one of the two supported, otherwise English. Stored via
/// shared_preferences (same package already used for "remember me" on the
/// login screen) so the choice survives a reload.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _load();
    return _deviceDefault();
  }

  Locale _deviceDefault() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'ar' ? const Locale('ar') : const Locale('en');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localeKey);
    if (saved != null) state = Locale(saved);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
