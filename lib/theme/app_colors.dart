// RepairX-OWNED FORK — Anchor palette. Do NOT overwrite on upstream sync
// (see pubspec description). Upstream original:
// daslaller/Papercraft lib/theme/app_colors.dart
//
// Values traced to RepairX's Anchor design system (design-system/tokens/
// colors.css and lib/core/theme/app_theme.dart AppColorsData.light):
// slate neutrals, blue-600 #2563EB interactive accent. Member names and
// `static const`-ness are a compile contract with the rest of the library —
// change VALUES only.
import 'package:flutter/material.dart';

class AppColors {
  // ── Surfaces (Anchor slate scale) ────────────────────────────────────────────
  static const background   = Color(0xFFF8FAFC); // slate-50 page bg
  static const panelBg      = Color(0xFFFFFFFF); // white (sidebars, cards)
  static const workspaceBg  = Color(0xFFF1F5F9); // slate-100 canvas bg
  static const card         = Color(0xFFFFFFFF); // white surface

  static const foreground        = Color(0xFF0F172A); // slate-900
  static const foregroundSecond  = Color(0xFF475569); // slate-600
  static const mutedForeground   = Color(0xFF64748B); // slate-500
  static const mutedForeground2  = Color(0xFF94A3B8); // slate-400
  static const cardForeground    = Color(0xFF0F172A); // slate-900

  static const primary            = Color(0xFF0F172A); // slate-900 dark-ink fills
  static const primaryForeground  = Color(0xFFF8FAFC); // slate-50

  static const secondary            = Color(0xFFF1F5F9); // slate-100 hover/track
  static const secondaryForeground  = Color(0xFF0F172A); // slate-900
  static const muted                = Color(0xFFF1F5F9); // slate-100

  // ── Accent (Anchor blue — the interactive/selected color) ────────────────────
  static const accent            = Color(0xFF2563EB); // Anchor blue-600
  static const accentForeground  = Color(0xFFFFFFFF);
  static const ring              = Color(0xFF2563EB); // Anchor blue-600

  // ── Semantic (RepairX AppColorsData.light) ───────────────────────────────────
  static const destructive        = Color(0xFFEF4444); // RepairX error red-500
  static const destructiveFgnd   = Color(0xFFFFFFFF);
  static const success            = Color(0xFF16A34A); // RepairX green-600
  static const warning            = Color(0xFFD97706); // RepairX amber-600

  // ── Glass / overlays (light theme only — dark mode deferred) ─────────────────
  static const glassBar           = Color(0xEEFFFFFF);
  static const glassPill          = Color(0xF7FFFFFF);
  static const hairline          = Color(0x1A000000);
  static const hairlineSoft       = Color(0x14000000);
  static const inkFaint           = Color(0x59000000);

  // ── Borders (hairlines — three prominence levels) ────────────────────────────
  static const border  = Color(0xFFE2E8F0); // slate-200 (dark)
  static const border2 = Color(0xFFEAEFF5); // slate-200/100 midpoint (mid)
  static const border3 = Color(0xFFF1F5F9); // slate-100 (light)
  static const input   = Color(0xFFE2E8F0); // slate-200

  /// One step past [border], for an outline meant to be *seen* rather than
  /// just separate — a selected card, a dashed hint. Rail's equivalent
  /// (`borderStrong` in `RailTokens`) is slate-300; same value here so a
  /// selected template card or a focused option reads the same weight it
  /// would in the host app.
  static const borderStrong = Color(0xFFCBD5E1); // slate-300

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
