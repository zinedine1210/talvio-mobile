import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens — sumber dari riset ui-ux-pro-max untuk produk HRIS/B2B
/// SaaS (palet teal+orange, flat design, Plus Jakarta Sans). Lihat
/// `design-system/talvio/MASTER.md` untuk detail lengkap & alasannya.
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
  final textTheme = GoogleFonts.plusJakartaSansTextTheme();

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
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
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 32),
  );
}
