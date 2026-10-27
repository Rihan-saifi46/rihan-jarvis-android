import 'package:flutter/material.dart';

class JarvisTheme {
  // Deep space & charcoal background shades
  static const Color background = Color(0xFF080B10);
  static const Color surface = Color(0xFF0F1520);
  static const Color surfaceLight = Color(0xFF16202E);
  static const Color surfaceBorder = Color(0xFF1F2D40);

  // Holographic emerald & cyan accents
  static const Color emerald = Color(0xFF00FF9D);
  static const Color emeraldDim = Color(0xFF00B36E);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanDim = Color(0xFF0099AA);
  static const Color glowCyan = Color(0x6600E5FF);
  static const Color glowEmerald = Color(0x6600FF9D);

  // Status & warnings
  static const Color errorRed = Color(0xFFFF4B6E);
  static const Color warningAmber = Color(0xFFFFB800);

  // Text colors
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF5A6578);

  // Gradients
  static const LinearGradient coreGradient = LinearGradient(
    colors: [emerald, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient userBubbleGradient = LinearGradient(
    colors: [Color(0xFF0A3B2E), Color(0xFF092C3D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient jarvisBubbleGradient = LinearGradient(
    colors: [Color(0xFF101722), Color(0xFF0C121A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: emerald,
      colorScheme: const ColorScheme.dark(
        primary: emerald,
        secondary: cyan,
        surface: surface,
        error: errorRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
