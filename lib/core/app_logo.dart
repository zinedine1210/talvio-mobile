import 'package:flutter/material.dart';

/// Logo aplikasi — baca dari `assets/images/logo.png`. File saat ini cuma
/// placeholder ("T" di atas warna brand); ganti isi file itu (nama/path
/// tetap sama) begitu logo final siap, tidak perlu ubah kode di sini.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
