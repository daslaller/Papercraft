import 'dart:typed_data';
import '../models/element_model.dart';
import '../models/template_model.dart';
import '../services/print_service.dart';
import '../services/token_service.dart';

/// Convenience print API — consistent `Papercraft*` naming for consumers.
///
/// This is a thin, named wrapper around [PrintService] so the public surface
/// of the package uses a uniform `Papercraft*` prefix.
///
/// ```dart
/// // Open OS print dialog:
/// await PapercraftPrint.print(
///   template: template,
///   elements: elements,
///   record: {'customer.name': 'Jane', 'order.number': 'WO-99'},
/// );
///
/// // Get raw PDF bytes (upload, email, etc.):
/// final Uint8List bytes = await PapercraftPrint.buildPdf(
///   template: template,
///   elements: elements,
///   record: record,
/// );
/// ```
abstract final class PapercraftPrint {
  // ── Single record ───────────────────────────────────────────────────────────

  /// Opens the OS print dialog filled with [record].
  static Future<void> print({
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) =>
      PrintService.printDirect(
        template: template,
        elements: elements,
        record: record,
        entityName: entityName,
        computedFields: computedFields,
      );

  /// Returns raw PDF bytes for a single record — no UI shown.
  static Future<Uint8List> buildPdf({
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) =>
      PrintService.buildPdf(
        template: template,
        elements: elements,
        record: record,
        entityName: entityName,
        computedFields: computedFields,
      );

  // ── Batch — one page per record ─────────────────────────────────────────────

  /// Opens the OS print dialog with one page per record in [records].
  ///
  /// ```dart
  /// await PapercraftPrint.printBatch(
  ///   template: template,
  ///   elements: elements,
  ///   records: workOrders.map((wo) => {
  ///     'work_order.number': wo.number,
  ///     'customer.name':     wo.customerName,
  ///   }).toList(),
  /// );
  /// ```
  static Future<void> printBatch({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) =>
      PrintService.printDirectBatch(
        template: template,
        elements: elements,
        records: records,
        entityName: entityName,
        computedFields: computedFields,
      );

  /// Returns a multi-page PDF with one page per record — no UI shown.
  static Future<Uint8List> buildPdfBatch({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) =>
      PrintService.buildPdfBatch(
        template: template,
        elements: elements,
        records: records,
        entityName: entityName,
        computedFields: computedFields,
      );

  // ── N-up sheet — tile labels on a larger sheet ──────────────────────────────

  /// Opens the OS print dialog with labels tiled N-up on [sheetWidthMm] ×
  /// [sheetHeightMm] pages (e.g. 30 labels on one A4 sheet).
  ///
  /// ```dart
  /// await PapercraftPrint.printSheet(
  ///   template: labelTemplate,   // label dimensions set here
  ///   elements: elements,
  ///   records: allWorkOrders,
  ///   sheetWidthMm: 210,         // A4 portrait
  ///   sheetHeightMm: 297,
  ///   marginMm: 10,
  ///   gapMm: 3,
  /// );
  /// ```
  static Future<void> printSheet({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    double sheetWidthMm = 210,
    double sheetHeightMm = 297,
    double marginMm = 8,
    double gapMm = 3,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) =>
      PrintService.printSheetDirect(
        template: template,
        elements: elements,
        records: records,
        sheetWidthMm: sheetWidthMm,
        sheetHeightMm: sheetHeightMm,
        marginMm: marginMm,
        gapMm: gapMm,
        entityName: entityName,
        computedFields: computedFields,
      );

  /// Returns raw N-up sheet PDF bytes — no UI shown.
  static Future<Uint8List> buildSheetPdf({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    double sheetWidthMm = 210,
    double sheetHeightMm = 297,
    double marginMm = 8,
    double gapMm = 3,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) =>
      PrintService.buildSheetPdf(
        template: template,
        elements: elements,
        records: records,
        sheetWidthMm: sheetWidthMm,
        sheetHeightMm: sheetHeightMm,
        marginMm: marginMm,
        gapMm: gapMm,
        entityName: entityName,
        computedFields: computedFields,
      );
}
