import 'package:flutter/material.dart';
import 'app_logo.dart';

/// AppBar bersama, dipakai di setiap layar tab utama (Home, Notifikasi,
/// Profil) supaya identitas brand (logo) konsisten di seluruh app, bukan
/// cuma di satu layar.
class TalvioAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TalvioAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(size: 28),
          const SizedBox(width: 10),
          Text(title),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
