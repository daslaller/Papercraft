// RepairX-OWNED FORK — Rail-style chrome primitives. Do NOT overwrite on
// upstream sync (see pubspec description).
//
// The uppercase micro-label ("DATA SOURCE", "LAYERS", "CANVAS SIZE") used to
// be hand-rolled at six call sites, each with its own copy of the same
// TextStyle — the exact drift the host app's "no copy-pasted widgets"
// convention exists to prevent. [PaperFieldLabel] and [PaperSectionLabel]
// are the one implementation; [PaperBadge] does the same job for the small
// tinted tags (template type, "Default") that used to be full pill shapes.
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_tokens.dart';

/// The uppercase, tracked micro-label above a value inside a control group —
/// "DATA SOURCE", "LAYERS", "CANVAS SIZE". Callers pass sentence case; this
/// owns the uppercasing so no call site can drift to a different casing
/// rule.
class PaperFieldLabel extends StatelessWidget {
  const PaperFieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppType.fieldLabel.copyWith(color: AppColors.mutedForeground),
    );
    if (trailing == null) return label;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Flexible(child: label), trailing!],
    );
  }
}

/// The quiet label that sits *above* a card or section — sentence case,
/// exactly as written. Distinct from [PaperFieldLabel]: this reads as a
/// short sentence, that reads as a value's name.
class PaperSectionLabel extends StatelessWidget {
  const PaperSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppType.sectionLabel.copyWith(color: AppColors.mutedForeground),
      );
}

/// Tone for [PaperBadge] — deliberately few. A badge answers "what kind of
/// thing is this / should I look twice at it", not a full palette.
enum PaperTone { neutral, accent, success, warning }

/// A small tinted tag — template type, "Default", printer association.
///
/// Rail's equivalent (`RailStatusBadge`) is a rounded-rect chip with an
/// icon, never a full pill: a badge should read as a label stuck onto a
/// corner, not as a button. This package has no bundled icon set beyond
/// Material, so the icon is optional rather than mandatory the way the host
/// app's Tabler-backed version is.
class PaperBadge extends StatelessWidget {
  const PaperBadge({
    super.key,
    required this.label,
    this.tone = PaperTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final PaperTone tone;
  final IconData? icon;
  final bool dense;

  /// Opaque, not alpha-blended. A badge on a flat card wouldn't show the
  /// difference, but this one also sits over the dashboard's live template
  /// preview (`_TemplateCard` in `dashboard_screen.dart`) — a translucent
  /// tint let whatever the shop's own design drew at that corner show
  /// through and read as garbled overlapping text. Rail's own status badge
  /// has the same property for the same reason (`AppStatusColors` are
  /// pre-mixed pastels, never alpha composited): chrome that can end up
  /// over arbitrary content has to be opaque to stay legible regardless of
  /// what's underneath.
  Color get _background => switch (tone) {
        PaperTone.neutral => AppColors.secondary,
        PaperTone.accent => Color.lerp(AppColors.accent, AppColors.card, 0.85)!,
        PaperTone.success => Color.lerp(AppColors.success, AppColors.card, 0.83)!,
        PaperTone.warning => Color.lerp(AppColors.warning, AppColors.card, 0.83)!,
      };

  Color get _foreground => switch (tone) {
        PaperTone.neutral => AppColors.foregroundSecond,
        PaperTone.accent => AppColors.accent,
        PaperTone.success => AppColors.success,
        PaperTone.warning => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    final fg = _foreground;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(AppTokens.radiusXs),
        // A badge that can land over a live preview needs to read as
        // something sitting *above* the content, not painted into the same
        // layer — the same reasoning as the opaque background above.
        boxShadow: AppColors.shadowSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppType.micro,
              fontWeight: AppTokens.fontMedium,
              color: fg,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
