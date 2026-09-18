import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double pageHorizontal = 20;
  static const double cardPadding = 16;

  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: pageHorizontal);
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius cardLarge = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius badge = BorderRadius.all(Radius.circular(sm));
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration emphasis = Duration(milliseconds: 280);

  static const Curve enter = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;
}
