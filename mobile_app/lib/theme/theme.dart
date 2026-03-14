import 'package:flutter/material.dart'; // ui kit
import 'package:google_fonts/google_fonts.dart'; // fonts

class AppTheme {
  static const Color pureBlack = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF0A0A0A);
  static const Color primaryIndigo = Color(0xFF7B8CFF);
  static const Color onPrimaryText = Color(0xFFFFFFFF);
  static const Color secondaryCyan = Color(0xFF00E5FF);
  static const Color errorRed = Color(0xFFFF6B6B);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color outlineColor = Color(0xFF444444);

  static ThemeData get darkTheme{
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A1A6E),
      brightness: Brightness.dark,
    ).copyWith(
      surface: surfaceDark,
      onSurface: onPrimaryText,
      primary: primaryIndigo,
      onPrimary: pureBlack,
      secondary: secondaryCyan,
      onSecondary: pureBlack,
      error: errorRed,
      onError: pureBlack,
      surfaceContainerHighest: surfaceVariant,
      outline: outlineColor,
      scrim: pureBlack,
    );



    
  }

}
