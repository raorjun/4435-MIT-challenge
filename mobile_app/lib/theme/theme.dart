import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color pureBlack = Color(0xFF000000); // scaffold bg
  static const Color surfaceDark = Color(0xFF0A0A0A); // cards, dialogs
  static const Color surfaceVariant = Color(0xFF1A1A1A); // elevated surfaces
  static const Color primaryIndigo = Color(0xFF7B8CFF); // 8.1:1 on black
  static const Color secondaryCyan = Color(0xFF00E5FF); // 9.4:1 on black
  static const Color onDark = Color(0xFFFFFFFF); // 21:1 on black
  static const Color errorRed = Color(0xFFFF6B6B);
  static const Color outlineColor = Color(0xFF444444);

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A6E), // deep indigo seed
          brightness: Brightness.dark,
        ).copyWith(
          // Surfaces — all near-black
          surface: surfaceDark,
          surfaceContainerHighest: surfaceVariant,
          onSurface: onDark,
          // Primary
          primary: primaryIndigo,
          onPrimary: pureBlack,
          // Secondary
          secondary: secondaryCyan,
          onSecondary: pureBlack,
          // Error
          error: errorRed,
          onError: pureBlack,
          // Misc
          outline: outlineColor,
          scrim: pureBlack,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: pureBlack,
      // ← forced pure black
      dialogTheme: const DialogThemeData(backgroundColor: surfaceDark),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureBlack,
        foregroundColor: onDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: pureBlack),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
      ),
      // Apply Lexend to every text style in the app globally
      textTheme: GoogleFonts.lexendTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(bodyColor: onDark, displayColor: onDark),
      iconTheme: const IconThemeData(color: secondaryCyan, size: 28),
      dividerTheme: const DividerThemeData(color: outlineColor, thickness: 1),
    );
  }
}
