import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — palet teal+orange, flat design, font Sora, sesuai
/// desain figma `Talvio.figcraft`. Lihat `design-system/talvio/MASTER.md`
/// untuk detail lengkap & alasannya.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF0D9488); // teal — brand utama
  static const primaryDark = Color(0xFF134E4A);
  static const secondary = Color(0xFF14B8A6);
  static const accent = Color(0xFFEA580C); // orange — CTA & sorotan
  static const background = Color(0xFFF0FDFA);

  // Status semantik — dipakai konsisten di badge, chip, dan state
  // absensi/approval di seluruh app (jangan pakai warna ad-hoc lain).
  static const statusSuccess = Color(0xFF16A34A); // hadir / approved
  static const statusWarning = Color(0xFFD97706); // pending / menunggu
  static const statusDanger = Color(0xFFDC2626); // rejected / mismatch
  static const statusInfo = Color(0xFF0284C7); // wfh / info netral
  static const statusNeutral = Color(0xFF64748B); // draft / tidak aktif
}

ThemeData buildTalvioTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    tertiary: AppColors.accent,
  );
  final radius = BorderRadius.circular(14);
  final textTheme = GoogleFonts.soraTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.sora(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: radius)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      // Figma selalu nunjukin label kecil di atas field + hint di dalamnya
      // bersamaan — default Material baru floating label setelah fokus/isi.
      floatingLabelBehavior: FloatingLabelBehavior.always,
      floatingLabelStyle: GoogleFonts.sora(
        color: const Color(0xFF134E4A),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: GoogleFonts.sora(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.sora(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 32),
  );
}
