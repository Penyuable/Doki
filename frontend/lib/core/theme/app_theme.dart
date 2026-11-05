import 'package:flutter/material.dart';

import '../../domain/models/card_model.dart';

/// Palet claymorphism pastel: warna solid lembut, tanpa gradien.
/// Semua widget membaca token di sini; jangan hardcode hex di halaman.
abstract final class AppTheme {
  // Permukaan.
  static const Color background = Color(0xFFE9E7F7);
  static const Color surface = Color(0xFFF6F5FD);
  static const Color surfaceHigh = Color(0xFFDEDBF2);

  // Tinta (teks & ikon).
  static const Color ink = Color(0xFF2B2752);
  static const Color inkSoft = Color(0xFF6F6A93);
  static const Color inkFaint = Color(0xFFA6A2C2);

  // Aksen merek.
  static const Color primary = Color(0xFF7A6CF0);
  static const Color primaryBright = Color(0xFF9D92F7);
  static const Color accent = Color(0xFF3FB6E8);
  static const Color pink = Color(0xFFFF8DB0);
  static const Color gold = Color(0xFFF5B83D);
  static const Color gem = Color(0xFF3FC7D9);

  // Status.
  static const Color success = Color(0xFF34BE8E);
  static const Color danger = Color(0xFFF2617F);
  static const Color warning = Color(0xFFF0A23B);
  static const Color info = Color(0xFF4C9BF0);
  static const Color attack = Color(0xFFFF8648);

  static Color rarityColor(Rarity rarity) => switch (rarity) {
        Rarity.common => const Color(0xFF9EA4BC),
        Rarity.uncommon => const Color(0xFF4CC48F),
        Rarity.rare => const Color(0xFF4C9BF0),
        Rarity.epic => const Color(0xFFA97CF2),
        Rarity.legendary => const Color(0xFFF2A93B),
        Rarity.master => const Color(0xFFF2617F),
      };

  static Color elementColor(CardElement element) => switch (element) {
        CardElement.fire => const Color(0xFFFF8648),
        CardElement.water => const Color(0xFF3FA9F0),
        CardElement.earth => const Color(0xFF6FBF4A),
        CardElement.air => const Color(0xFF7FC8D8),
        CardElement.voidElement => const Color(0xFF9B7CF2),
      };

  /// Versi pastel warna elemen untuk badan kartu clay.
  static Color elementPastel(CardElement element) => switch (element) {
        CardElement.fire => const Color(0xFFFFD9C4),
        CardElement.water => const Color(0xFFCDE8FB),
        CardElement.earth => const Color(0xFFDAF0C9),
        CardElement.air => const Color(0xFFD9F0F4),
        CardElement.voidElement => const Color(0xFFE3D9FB),
      };

  static IconData elementIcon(CardElement element) => switch (element) {
        CardElement.fire => Icons.local_fire_department_rounded,
        CardElement.water => Icons.water_drop_rounded,
        CardElement.earth => Icons.terrain_rounded,
        CardElement.air => Icons.air_rounded,
        CardElement.voidElement => Icons.blur_on_rounded,
      };

  static ThemeData clay() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      surface: surface,
      onSurface: ink,
      error: danger,
    );

    final text = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
    ).textTheme.apply(bodyColor: ink, displayColor: ink);

    final round = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        bodySmall: text.bodySmall?.copyWith(color: inkSoft),
      ),
      iconTheme: const IconThemeData(color: ink),
      cardTheme: CardThemeData(color: surface, elevation: 0, shape: round),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: inkFaint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        side: BorderSide.none,
        shape: StadiumBorder(),
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: ink),
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: primary,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? Colors.white : inkSoft,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? ink : inkSoft,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 52),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: primary.withValues(alpha: 0.45),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: ink,
          backgroundColor: surface,
          side: BorderSide.none,
          elevation: 3,
          shadowColor: surfaceHigh,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: const DividerThemeData(color: surfaceHigh, thickness: 1.5),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceHigh,
        circularTrackColor: surfaceHigh,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(const StadiumBorder()),
          side: WidgetStateProperty.all(BorderSide.none),
          minimumSize: WidgetStateProperty.all(const Size(44, 46)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? primary : surfaceHigh,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : inkSoft,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? Colors.white : inkSoft,
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? primary : inkFaint,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }
}
