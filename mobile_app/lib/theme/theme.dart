import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color pureBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF000000);
  static const Color surfaceVariant = Color(0xFF000000);

  // Mint-forward palette with a muted gray-pink navigation surface.
  static const Color primaryMint = Color(0xFFCFFFC9);
  static const Color secondarySeed = Color(0xFF9ED89C);
  static const Color navBarBackground = Color(0xFF000000);
  static const Color inactiveLabel = Color(0xFFD0C0CA);

  static const Color onDark = Color(0xFFFFFFFF);
  static const Color errorRed = Color(0xFFFF6B6B);
  static const Color outlineColor = Color(0xFF444444);
  static const double cornerRadius = 16;

  static ThemeData get darkTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryMint,
          brightness: Brightness.dark,
        ).copyWith(
          // Surfaces — all near-black
          surface: surfaceDark,
          surfaceContainerHighest: surfaceVariant,
          onSurface: onDark,
          // Primary
          primary: primaryMint,
          onPrimary: Color(0xFF18331A),
          // Secondary
          secondary: secondarySeed,
          onSecondary: Color(0xFF18331A),
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
      scaffoldBackgroundColor: surfaceDark,
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceVariant,
        titleTextStyle: TextStyle(
          color: onDark,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: onDark,
          fontSize: 18,
          height: 1.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: onDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBarBackground,
        height: 84,
        elevation: 6,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: primaryMint.withValues(alpha: 0.20),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryMint, size: 34);
          }
          return const IconThemeData(color: inactiveLabel, size: 30);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.lexend(
              color: primaryMint,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            );
          }
          return GoogleFonts.lexend(
            color: inactiveLabel,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: GoogleFonts.lexend(
          color: onDark,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
        ),
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
      iconTheme: const IconThemeData(color: primaryMint, size: 28),
      dividerTheme: const DividerThemeData(color: outlineColor, thickness: 1),
    );
  }
}
