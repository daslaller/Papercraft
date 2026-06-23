import 'package:flutter/material.dart';

class AppColors {
  // ── Spec-aligned palette (§2) ────────────────────────────────────────────────
  static const background   = Color(0xFFF5F5F7); // spec "bg"
  static const panelBg      = Color(0xFFFBFBFD); // spec "panelBg" (sidebars, cards)
  static const workspaceBg  = Color(0xFFF0F0F2); // spec "canvasBg"
  static const card         = Color(0xFFFFFFFF); // spec "surface"

  static const foreground        = Color(0xFF1D1D1F); // spec "ink"
  static const foregroundSecond  = Color(0xFF515154); // spec "inkSecondary"
  static const mutedForeground   = Color(0xFF86868B); // spec "inkTertiary"
  static const mutedForeground2  = Color(0xFFA1A1A6); // spec "inkQuaternary"
  static const cardForeground    = Color(0xFF1D1D1F);

  static const primary            = Color(0xFF1D1D1F);
  static const primaryForeground  = Color(0xFFFAFAFA);

  static const secondary            = Color(0xFFEDEDF0); // spec "hover"/"segmentTrack"
  static const secondaryForeground  = Color(0xFF1D1D1F);
  static const muted                = Color(0xFFEDEDF0);

  // ── Accent (the one blue — §2) ──────────────────────────────────────────────
  static const accent            = Color(0xFF0A66D6); // spec accent
  static const accentForeground  = Color(0xFFFFFFFF);
  static const ring              = Color(0xFF0A66D6);

  // ── Semantic ─────────────────────────────────────────────────────────────────
  static const destructive        = Color(0xFFC0392B); // spec "danger"
  static const destructiveFgnd   = Color(0xFFFFFFFF);
  static const success            = Color(0xFF34C759); // spec "success"

  // ── Borders (hairlines — three prominence levels) ────────────────────────────
  static const border  = Color(0xFFE0E0E4); // spec hairline dark
  static const border2 = Color(0xFFECECED); // spec hairline mid
  static const border3 = Color(0xFFF0F0F2); // spec hairline light
  static const input   = Color(0xFFE0E0E4);

  // ── Shadows (§2) ─────────────────────────────────────────────────────────────
  static const shadowSm = [
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x08000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const shadowMd = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 4,  offset: Offset(0, 2)),
  ];
  // Panel / floating pill shadow
  static const shadowLg = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 3,  offset: Offset(0, 1)),
  ];
  static const shadowXL = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 48, offset: Offset(0, 16)),
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
  ];
  // Paper (canvas element) — spec: 0 14px 50px rgba(0,0,0,0.15) + 0 2px 8px rgba(0,0,0,0.06)
  static const shadowCanvas = [
    BoxShadow(color: Color(0x26000000), blurRadius: 50, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8,  offset: Offset(0, 2)),
  ];
  // Cards — spec: 0 1px 3px rgba(0,0,0,0.08)
  static const shadowCard = [
    BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

/// Produces a color with a fractional alpha (0.0–1.0).
Color withAlpha(Color color, double opacity) =>
    color.withValues(alpha: opacity);
