import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'app_locale';
const _supported = {'en', 'ar'};

/// Persisted UI language (English/Arabic) — defaults to the device locale
/// when it's one of the two supported, otherwise English.
///
/// The saved value is now read *before* the first frame (see [preload],
/// called from `main()`). Previously `build()` kicked off an un-awaited
/// `_load()` and returned the device default, so an Arabic-preferring user
/// on an English handset watched the entire app render in English and then
/// snap to Arabic — including a full LTR→RTL flip — on every cold start.
class LocaleController extends Notifier<Locale> {
  /// Reads the stored preference once, before `runApp`, so the very first
  /// frame is already in the right language.
  static Locale? _initial;

  static Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_localeKey);
      if (saved != null && _supported.contains(saved)) {
        _initial = Locale(saved);
      }
    } catch (_) {
      // A shared_preferences failure must not stop the app booting; the
      // device default below is a fine fallback.
    }
  }

  @override
  Locale build() => _initial ?? _deviceDefault();

  Locale _deviceDefault() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'ar' ? const Locale('ar') : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    if (!_supported.contains(locale.languageCode)) return;
    state = locale;
    _initial = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
