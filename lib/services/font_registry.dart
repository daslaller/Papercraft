/// Where Papercraft gets its fonts.
///
/// By default the canvas styles text through `google_fonts` and the PDF painter
/// downloads the matching TTFs from `fonts.gstatic.com`. That works, and it is
/// a reasonable default for a package that cannot assume anything about its
/// host — but it has two sharp edges:
///
/// - **Offline, the PDF loses more than its typeface.** `PrintService` falls
///   back to `pw.Font.helvetica()`, one of the standard PDF Type 1 fonts, which
///   has no Unicode support. The `pdf` package then *throws* on the first
///   character outside Latin-1 — an em dash, a curly quote, an ellipsis — and
///   because that happens during `Document.save` it takes the whole document
///   with it. A shop with no internet does not get a plainer invoice; it gets
///   no invoice.
/// - **A host that already ships the font pays twice.** RepairX bundles Inter
///   at five weights as Flutter assets and still had every PDF fetch it again.
///
/// Both are fixed by letting the host say "I have these fonts". A host that
/// says nothing keeps exactly the old behaviour.
library;

import 'package:pdf/widgets.dart' as pw;

/// The four faces the PDF painter draws with.
class PapercraftPdfFonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font mono;

  const PapercraftPdfFonts({
    required this.regular,
    required this.bold,
    required this.italic,
    required this.mono,
  });
}

abstract final class FontRegistry {
  /// Font families the host has registered as Flutter assets.
  ///
  /// The canvas renderer styles these with a plain `TextStyle(fontFamily: …)`
  /// rather than `GoogleFonts.getFont`, so they render without a network round
  /// trip — and, more importantly, render *at all* when there is no network.
  /// With `GoogleFonts.config.allowRuntimeFetching = false` and no bundled
  /// face, text at a weight the platform default lacks draws as tofu boxes,
  /// which is easy to miss because normal-weight text still looks fine.
  static Set<String> bundledFamilies = const {};

  /// Supplies the PDF faces, replacing the `fonts.gstatic.com` download.
  ///
  /// Set this to fonts with the coverage your documents need. A host that
  /// leaves it null keeps the download, with the Helvetica fallback and its
  /// Latin-1 limit described above.
  static Future<PapercraftPdfFonts> Function()? pdfFonts;

  /// Whether [family] should be styled from bundled assets.
  static bool isBundled(String family) => bundledFamilies.contains(family);

  /// Restores the defaults. For tests.
  static void reset() {
    bundledFamilies = const {};
    pdfFonts = null;
  }
}
