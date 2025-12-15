import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primaryDark = Color(0xFF0D0D0D);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color cardDark = Color(0xFF252525);

  static const Color accentTeal = Color(0xFF00D9B5);
  static const Color accentCyan = Color(0xFF00B4D8);
  static const Color accentPurple = Color(0xFF9D4EDD);

  static const Color dangerRed = Color(0xFFFF4D6D);
  static const Color safeGreen = Color(0xFF06D6A0);
  static const Color warningYellow = Color(0xFFFFD166);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [accentTeal, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF4D6D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF06D6A0), Color(0xFF00D9B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: ColorScheme.dark(
        primary: accentTeal,
        secondary: accentCyan,
        surface: surfaceDark,
        error: dangerRed,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            headlineLarge: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            headlineMedium: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            titleLarge: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            bodyLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white60,
            ),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentTeal,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
    );
  }
}

// Glassmorphic container decoration
BoxDecoration glassmorphicDecoration({
  double opacity = 0.1,
  double borderRadius = 24,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: Colors.white.withAlpha((opacity * 255).round()),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: borderColor ?? Colors.white.withAlpha(51),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(51),
        blurRadius: 20,
        spreadRadius: -5,
      ),
    ],
  );
}

// Glassmorphic blur filter
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.opacity = 0.1,
    this.borderRadius = 24,
    this.padding,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: glassmorphicDecoration(
            opacity: opacity,
            borderRadius: borderRadius,
            borderColor: borderColor,
          ),
          child: child,
        ),
      ),
    );
  }
}
