import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'app_locale';

/// Defaults to Indonesian, then swaps to whatever was persisted (if
/// anything) once SharedPreferences resolves — a one-frame flash to the
/// default locale on cold start is an acceptable tradeoff for not blocking
/// the first frame on disk I/O.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadPersisted();
    return const Locale('id');
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
