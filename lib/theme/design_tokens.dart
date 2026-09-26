import 'package:flutter/material.dart';

/// Values from `design/tokens.json` (design handoff v1), the single source of
/// truth for the new visual theme. Only the tokens already used by screens
/// are listed; phase 1 (theme) completes this file and migrates the rest of
/// the app.
abstract final class DesignColors {
  static const primary = Color(0xFFF0523C);
  static const onPrimary = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF222222);
  static const textSecondary = Color(0xFF555555);
  static const textTertiary = Color(0xFF8A8A8A);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const borderSubtle = Color(0xFFF2F2F2);

  /// Off state of the settings toggle track (prototype `settings` screen).
  static const toggleTrackOff = Color(0xFFD5D5D8);
}

abstract final class DesignSpacing {
  static const xs = 4.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xxl = 24.0;
}

abstract final class DesignRadius {
  static const lg = 16.0;
}

abstract final class DesignTextStyles {
  /// typography.scale.body
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: DesignColors.textPrimary,
  );

  /// Settings group title in the prototype: caption size, weight 500,
  /// uppercase.
  static const settingsGroupTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.4,
    color: DesignColors.textTertiary,
  );
}

abstract final class DesignShadows {
  /// elevation.card: 0 1px 3px rgba(0,0,0,0.05)
  static const card = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 1), blurRadius: 3),
  ];
}
