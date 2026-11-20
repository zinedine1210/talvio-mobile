import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// "10e Bantuan" — static contact pointer. No in-app support ticket
/// system exists, so this doesn't pretend to be one.
class ProfileHelpScreen extends StatelessWidget {
  const ProfileHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(t.helpMenuLabel)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.support_agent_outlined, color: Color(0xFF0D9488)),
                const SizedBox(width: 12),
                Expanded(child: Text(t.helpContactMessage)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
