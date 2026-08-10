// RepairX-OWNED FORK — Rail component geometry. Do NOT overwrite on upstream
// sync (see pubspec description).
//
// Anchor supplies the palette (`app_colors.dart`); Rail supplies the shape.
// The previous version of this file paired Anchor's colours with a serif
// display face (Playfair) for headings — a leftover from Papercraft's
// original standalone-app spec, from before RepairX's Anchor palette was
// adopted (see the history of `app_colors.dart`). Rail has no display serif
// anywhere in its type ramp: one typeface, a tighter size scale, thinner
// borders, flatter elevation. This file now matches that, the same way
// `app_colors.dart` already matches Anchor's colours.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        surface: AppColors.background,
        onSurface: AppColors.foreground,
        primary: AppColors.primary,
        onPrimary: AppColors.primaryForeground,
        secondary: AppColors.secondary,
        onSecondary: AppColors.secondaryForeground,
        tertiary: AppColors.accent,
        onTertiary: AppColors.accentForeground,
        error: AppColors.destructive,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // One typeface. Anchor-era Papercraft paired Inter body text with a
      // Playfair Display headline face; Rail's ramp never introduces a
      // second family, so headlineLarge/Medium and titleLarge (read by the
      // dashboard hero and the "New Template"/"Preview" dialog titles) are
      // Inter too now, just heavier and tighter-tracked than body text.
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: const TextStyle(
          fontSize: AppType.display,
          fontWeight: AppTokens.fontSemibold,
          letterSpacing: AppType.trackingTight,
          height: 1.2,
          color: AppColors.foreground,
        ),
        headlineMedium: const TextStyle(
          fontSize: 20,
          fontWeight: AppTokens.fontSemibold,
          letterSpacing: AppType.trackingTight,
          height: 1.25,
          color: AppColors.foreground,
        ),
        titleLarge: AppType.pageTitle.copyWith(color: AppColors.foreground),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        // 1.5, not 2 — Rail's borders read thinner throughout; a 2px focus
        // ring was the one place this package still drew an Anchor-weight
        // line.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: AppColors.ring, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dividerColor: AppColors.border,
      // Flatter elevation: a hairline border carries the edge, and the
      // subtle boxShadow that reads as "Rail" comes from AppColors.shadowCard
      // on the widgets that draw their own DecoratedBox (Material's
      // CardTheme elevation only offers Flutter's fixed elevation curve, not
      // Rail's custom low-alpha shadow — see the dashboard template card).
      cardTheme: const CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusXl)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}
