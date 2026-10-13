import 'package:flutter/material.dart';

class AppColors {
  // Deep, solid greens for better contrast
  static const Color brandGreen = Color(0xFF2E7D32); // Deep rich green
  static const Color lightGreen = Color(0xFF43A047); // Solid accent green

  // Playful primary & secondary colors
  static const Color primaryBlue = Color(0xFF3498DB); // Friendly blue
  static const Color secondaryBlue = Color(0xFF5DADE2); // Lighter sky blue
  static const Color deepBlue = Color(0xFF2980B9); // Rich contrast blue

  // Warm accents
  static const Color accentCoral = Color(0xFFe85021); // Warm vibrant coral
  static const Color accentOrange = Color(0xFFF39C12); // Bright orange
  static const Color accentYellow = Color(0xFFF1C40F); // Cheerful yellow
  static const Color accentPurple = Color(0xFF9B59B6); // Playful purple

  // Neutrals / Backgrounds
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceGray = Color(
    0xFFF4F9F8,
  ); // Soft mint/gray airy background
  static const Color darkGray = Color(0xFFBDC3C7);

  // Text Colors
  static const Color textMain = Color(
    0xFF2C3E50,
  ); // Darker blue-grey for soft readability
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF95A5A6); // Soft grey
}

class AppStyles {
  // Border Radii
  static final BorderRadius radiusSmall = BorderRadius.circular(12);
  static final BorderRadius radiusMedium = BorderRadius.circular(16);
  static final BorderRadius radiusLarge = BorderRadius.circular(24);
  static final BorderRadius radiusPill = BorderRadius.circular(999);

  // Gamified Box Shadows
  static final List<BoxShadow> playfulShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static final List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 0,
      offset: const Offset(0, 4), // Chunky bottom shadow
    ),
  ];

  static final List<BoxShadow> noShadow = [];
}
