import 'package:flutter/material.dart';

/// Geometry and spacing from tokens.css:51-92 (px treated as dp).
abstract final class ClayRadii {
  static const double s = 14;
  static const double m = 22;
  static const double l = 30;
  static const double pill = 999;
}

abstract final class ClaySpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
}

abstract final class ClaySize {
  /// Minimum interactive target.
  static const double touch = 48;
  static const double touchTab = 44;
  static const double pillMin = 28;
  static const double listen = 56;
  static const double ringDefault = 96;
  static const double avatarDefault = 44;
}

/// Type scale (web rem * 16) and weights.
abstract final class ClayType {
  static const double xs = 14;
  static const double s = 16;
  static const double m = 18;
  static const double l = 22;
  static const double xl = 28;
  static const double xxl = 36;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight heavy = FontWeight.w800;
}

/// Motion tokens. Read them through ClayMotion so reduced motion is honoured.
abstract final class ClayDurations {
  static const press = Duration(milliseconds: 120);
  static const lift = Duration(milliseconds: 180);
  static const sheet = Duration(milliseconds: 320);
  static const entrance = Duration(milliseconds: 450);
  static const ring = Duration(milliseconds: 600);
  static const bar = Duration(milliseconds: 900);
  static const shimmer = Duration(milliseconds: 1400);
}

abstract final class ClayCurves {
  static const bounce = Cubic(0.34, 1.56, 0.64, 1);
  static const out = Cubic(0.22, 0.8, 0.3, 1);
}
