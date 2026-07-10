import 'package:flutter/material.dart';

/// DonkeyWork Design System tokens (from the design-system reference notes).
abstract final class DwColors {
  // Dark backgrounds
  static const bgPrimary = Color(0xFF0A0D12);
  static const bgSecondary = Color(0xFF0F1318);
  static const bgTertiary = Color(0xFF151A21);
  static const bgElevated = Color(0xFF1A2028);

  // Dark text
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF94A3B8);
  static const textTertiary = Color(0xFF64748B);
  static const textMuted = Color(0xFF475569);

  // Accent (dark)
  static const accent = Color(0xFF22D3EE);
  static const accentHover = Color(0xFF06B6D4);

  // Semantic (dark)
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  // Light backgrounds
  static const lightBgPrimary = Color(0xFFFFFFFF);
  static const lightBgSecondary = Color(0xFFF8FAFC);
  static const lightBgTertiary = Color(0xFFF1F5F9);
  static const lightBgElevated = Color(0xFFE2E8F0);

  // Light text
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextTertiary = Color(0xFF64748B);

  // Accent (light — darker cyan for contrast)
  static const lightAccent = Color(0xFF0891B2);
  static const lightAccentHover = Color(0xFF0E7490);

  static const lightSuccess = Color(0xFF059669);
  static const lightWarning = Color(0xFFD97706);
  static const lightError = Color(0xFFDC2626);

  static const gradientStart = Color(0xFF06B6D4); // cyan-500/600
  static const gradientEnd = Color(0xFF2563EB); // blue-600
}

/// Per-brightness semantic lookups used by widgets.
class DwPalette extends ThemeExtension<DwPalette> {
  const DwPalette({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgTertiary,
    required this.bgElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentHover,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
    required this.borderStrong,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgTertiary;
  final Color bgElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentHover;
  final Color success;
  final Color warning;
  final Color error;
  final Color border;
  final Color borderStrong;

  static const dark = DwPalette(
    bgPrimary: DwColors.bgPrimary,
    bgSecondary: DwColors.bgSecondary,
    bgTertiary: DwColors.bgTertiary,
    bgElevated: DwColors.bgElevated,
    textPrimary: DwColors.textPrimary,
    textSecondary: DwColors.textSecondary,
    textTertiary: DwColors.textTertiary,
    accent: DwColors.accent,
    accentHover: DwColors.accentHover,
    success: DwColors.success,
    warning: DwColors.warning,
    error: DwColors.error,
    border: Color(0x14FFFFFF), // white 8%
    borderStrong: Color(0x1FFFFFFF), // white 12%
  );

  static const light = DwPalette(
    bgPrimary: DwColors.lightBgPrimary,
    bgSecondary: DwColors.lightBgSecondary,
    bgTertiary: DwColors.lightBgTertiary,
    bgElevated: DwColors.lightBgElevated,
    textPrimary: DwColors.lightTextPrimary,
    textSecondary: DwColors.lightTextSecondary,
    textTertiary: DwColors.lightTextTertiary,
    accent: DwColors.lightAccent,
    accentHover: DwColors.lightAccentHover,
    success: DwColors.lightSuccess,
    warning: DwColors.lightWarning,
    error: DwColors.lightError,
    border: Color(0xFFE2E8F0), // slate-200
    borderStrong: Color(0xFFCBD5E1), // slate-300
  );

  @override
  DwPalette copyWith() => this;

  @override
  DwPalette lerp(DwPalette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension DwPaletteContext on BuildContext {
  DwPalette get dw => Theme.of(this).extension<DwPalette>()!;
}

ThemeData donkeyWorkTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark ? DwPalette.dark : DwPalette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: palette.bgPrimary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.bgPrimary,
      primary: palette.accent,
      error: palette.error,
    ),
  );

  return base.copyWith(
    extensions: [palette],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bgSecondary,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.bgTertiary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.bgTertiary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: palette.accent.withValues(alpha: 0.5)),
      ),
      labelStyle: TextStyle(color: palette.textSecondary),
      hintStyle: TextStyle(color: palette.textTertiary),
    ),
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: palette.textSecondary,
      textColor: palette.textPrimary,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.bgElevated,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.bgElevated,
      contentTextStyle: TextStyle(color: palette.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Primary action button with the DonkeyWork cyan→blue gradient.
class DwGradientButton extends StatelessWidget {
  const DwGradientButton({super.key, required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [DwColors.gradientStart, DwColors.gradientEnd]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: DwColors.accent.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        child: child,
      ),
    );
  }
}
