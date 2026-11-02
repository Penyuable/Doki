import 'package:flutter/material.dart';

import '../../domain/models/card_model.dart';

abstract final class AppTheme {
  static const Color background = Color(0xFF0B0A12);
  static const Color surface = Color(0xFF15131F);
  static const Color surfaceHigh = Color(0xFF1E1B2C);
  static const Color primary = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFF22D3EE);
  static const Color gold = Color(0xFFFFC857);

  static Color rarityColor(Rarity rarity) => switch (rarity) {
    Rarity.common => const Color(0xFF9AA3B2),
    Rarity.uncommon => const Color(0xFF4ADE80),
    Rarity.rare => const Color(0xFF60A5FA),
    Rarity.epic => const Color(0xFFC084FC),
    Rarity.legendary => const Color(0xFFFBBF24),
    Rarity.master => const Color(0xFFFB7185),
  };

  static Color elementColor(CardElement element) => switch (element) {
    CardElement.fire => const Color(0xFFF97316),
    CardElement.water => const Color(0xFF38BDF8),
    CardElement.earth => const Color(0xFF84CC16),
    CardElement.air => const Color(0xFFE2E8F0),
    CardElement.voidElement => const Color(0xFFA78BFA),
  };

  static IconData elementIcon(CardElement element) => switch (element) {
    CardElement.fire => Icons.local_fire_department_rounded,
    CardElement.water => Icons.water_drop_rounded,
    CardElement.earth => Icons.terrain_rounded,
    CardElement.air => Icons.air_rounded,
    CardElement.voidElement => Icons.blur_on_rounded,
  };

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      secondary: accent,
      surface: surface,
      onSurface: const Color(0xFFF4F1FF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFFF4F1FF) : const Color(0xFF9AA3B2),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: const Color(0xFFC4B5FD),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: Color(0xFFF4F1FF)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.06),
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFF2A2438),
      ),
    );
  }
}
