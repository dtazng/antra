import 'package:flutter/material.dart';

/// Aurora palette — the primary color constants used across all themed surfaces.
class AntraColors {
  AntraColors._();

  static const Color auroraDeepNavy = Color(0xFF0D0F1A);
  static const Color auroraNavy = Color(0xFF121428);
  static const Color auroraIndigo = Color(0xFF1E1F5E);
  static const Color auroraViolet = Color(0xFF2D1B6B);
  static const Color auroraElectricBlue = Color(0xFF2563EB);
  static const Color auroraMagenta = Color(0xFFD946EF);
  static const Color auroraTeal = Color(0xFF14B8A6);
  static const Color auroraCoralHint = Color(0xFFF97316);

  // Glass surface modifiers — applied as withValues(alpha: x) on Colors.white/black
  static const double glassTintOpacityCard = 0.14;
  static const double glassTintOpacityBar = 0.10;
  static const double glassTintOpacityModal = 0.18;
  static const double glassTintOpacityChip = 0.08;
  static const double glassTintOpacityHero = 0.16;
  static const double glassBorderOpacity = 0.15;
  static const double chipGlassBorderOpacity = 0.08;
  static const double glassShadowAmbientOpacity = 0.25;
  static const double glassShadowFillOpacity = 0.10;
}

/// Border-radius tokens.
class AntraRadius {
  AntraRadius._();

  static const double card = 20;
  static const double modal = 28;
  static const double chip = 16;
  static const double avatar = 22;
  static const double tabBar = 30;
}

/// Animation duration and curve tokens.
class AntraMotion {
  AntraMotion._();

  static const Duration springExpand = Duration(milliseconds: 280);
  static const Duration springCollapse = Duration(milliseconds: 220);
  static const Duration fadeDismiss = Duration(milliseconds: 200);
  static const Duration slideInsert = Duration(milliseconds: 350);
  static const Duration tapFeedback = Duration(milliseconds: 100);
  static const Duration backgroundCycle = Duration(seconds: 30);

  static const Curve expandCurve = Curves.easeOutCubic;
  static const Curve collapseCurve = Curves.easeInCubic;
  static const Curve dismissCurve = Curves.easeOut;
  static const Curve insertCurve = Curves.easeOutBack;
  static const Curve tapCurve = Curves.easeOut;
}
