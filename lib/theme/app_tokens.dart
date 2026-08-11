// RepairX-OWNED FORK — Rail geometry tokens. Do NOT overwrite on upstream
// sync (see pubspec description); see app_colors.dart for the same rule
// applied to colour.
//
// RepairX's design system now separates two axes that used to be one:
// **Anchor** is the colour scheme (`app_colors.dart`, unchanged by this
// file), **Rail** is the component geometry — a denser scale, thinner
// borders, flatter elevation and a tighter type ramp than the original
// Anchor-era chrome this package shipped with. Source of truth on the host
// side: `mobilx_repairx/lib/ui/rail/rail_tokens.dart` and
// `mobilx_repairx/lib/core/theme/app_theme.dart` (`AppTokens`). Papercraft
// cannot import either — it is a standalone package RepairX depends on, not
// the other way round — so the *shape* of that scale is reproduced here,
// scaled for a canvas editor rather than transcribed pixel-for-pixel from a
// marketing site.
//
// Member names and `static const`-ness are a compile contract with the rest
// of the library — change VALUES only.
import 'package:flutter/material.dart';

/// The shared Anchor/Rail spacing + radius scale. Anchor and Rail draw from
/// the same numeric scale; Rail just uses the denser end of it more often.
class AppTokens {
  const AppTokens._();

  // ── Spacing scale ────────────────────────────────────────────────────────
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // ── Corner radius scale ──────────────────────────────────────────────────
  static const double radiusXs = 4;   // badges, tags
  static const double radiusSm = 6;   // chips, small controls
  static const double radiusMd = 8;   // inputs, buttons
  static const double radiusLg = 12;  // grouped controls, size pickers
  static const double radiusXl = 16;  // cards, dialogs
  static const double radiusFull = 9999; // pills, avatars

  // ── Font weights ─────────────────────────────────────────────────────────
  static const FontWeight fontNormal = FontWeight.w400;
  static const FontWeight fontMedium = FontWeight.w500;
  static const FontWeight fontSemibold = FontWeight.w600;
  static const FontWeight fontBold = FontWeight.w700;
}

/// Rail's type ramp, reproduced for Papercraft's own chrome. Two rules carry
/// over unchanged from the host's measured version:
///
/// - **Section labels are sentence case; field labels are the only thing
///   that shouts.** [sectionLabel] sits above a group of controls ("Data
///   source", "Canvas size") and reads as language. [fieldLabel] sits
///   *inside* a control stack, uppercase and tracked, for values rather than
///   sentences ("SKU", "LAYERS").
/// - **Field labels are regular weight, not bold.** The host's design system
///   shipped bold uppercase micro-labels for a while and then measured its
///   own reference site: at 11px with letter-spacing, bold reads as a second
///   heading fighting the value under it. Papercraft's sidebars carried the
///   same bold-uppercase habit independently; this corrects it the same way.
class AppType {
  const AppType._();

  static const double micro = 11;  // uppercase field labels
  static const double xs = 12;
  static const double sm = 13;
  static const double md = 15;
  static const double cardTitle = 14;
  static const double title = 18;
  static const double display = 26;

  /// Tracking, in logical pixels. Rail expresses these as ems on the CSS
  /// side (`0.06em`, `-0.01em`); the constants here are that ratio applied
  /// at the size each style actually uses.
  static const double trackingWide = 0.6;   // ~0.055em at 11px, field labels
  static const double trackingTight = -0.2; // ~-0.013em at 15-18px, titles

  /// The uppercase, tracked micro-label used *inside* a control group, above
  /// a value — mirrors the host's `RailFieldLabel`. Regular weight (see
  /// class doc); callers only supply the text, this owns the casing.
  static const TextStyle fieldLabel = TextStyle(
    fontSize: micro,
    fontWeight: AppTokens.fontNormal,
    letterSpacing: trackingWide,
    height: 1.5,
  );

  /// The quiet label that sits *above* a card or panel section — sentence
  /// case, never uppercased by the caller.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: xs,
    fontWeight: AppTokens.fontMedium,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle cardTitleStyle = TextStyle(
    fontSize: cardTitle,
    fontWeight: AppTokens.fontSemibold,
    letterSpacing: 0,
    height: 1.35,
  );

  /// A page or dialog title — one step below Anchor's old 20-24px chrome
  /// headings, matching Rail's denser type ramp.
  static const TextStyle pageTitle = TextStyle(
    fontSize: title,
    fontWeight: AppTokens.fontSemibold,
    letterSpacing: trackingTight,
    height: 1.25,
  );

  static const TextStyle caption = TextStyle(
    fontSize: xs,
    letterSpacing: 0,
    height: 1.4,
  );

  static const TextStyle body = TextStyle(
    fontSize: sm,
    letterSpacing: 0,
    height: 1.45,
  );
}
