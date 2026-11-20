import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale_provider.dart';
import '../../../l10n/app_localizations.dart';

/// "10d Bahasa" — reuses the same localeProvider the old inline dropdown
/// used, just as a dedicated picker screen matching figma's nav pattern.
class ProfileLanguageScreen extends ConsumerWidget {
  const ProfileLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    Widget option(Locale value, String label) => DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: RadioListTile<Locale>(
            value: value,
            groupValue: locale,
            onChanged: (l) {
              if (l != null) ref.read(localeProvider.notifier).setLocale(l);
            },
            title: Text(label),
            activeColor: const Color(0xFF0D9488),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(t.languageMenuTooltip)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          option(const Locale('id'), 'Bahasa Indonesia'),
          const SizedBox(height: 10),
          option(const Locale('en'), 'English'),
        ],
      ),
    );
  }
}
