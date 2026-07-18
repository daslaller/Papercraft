import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/element_model.dart';
import '../models/template_model.dart';
import '../services/print_service.dart';
import '../services/printer_provider.dart';
import '../services/token_service.dart';
import 'common/printer_unavailable_dialog.dart';

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
/// // Silent print to the template's associated printer:
/// await PapercraftPrint.printToAssociatedPrinter(
///   context: context, // optional — shows error dialog if unavailable
///   template: template,
///   elements: elements,
///   record: record,
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

  /// Prints silently to the printer associated with [template].
  ///
  /// Resolves [Template.printerId] / [Template.printerName] via
  /// [PrinterRegistry.active]. On success, sends the PDF to that printer.
  ///
  /// If the printer cannot be resolved (e.g. a local OS printer not present
  /// on this machine):
  /// - Throws [PrinterUnavailableException]
  /// - If [context] is provided and mounted, also shows a themed error dialog
  ///
  /// Pass [context] from UI code; omit it from pure service / background code.
  static Future<void> printToAssociatedPrinter({
    BuildContext? context,
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
    PrinterProvider? printerProvider,
  }) async {
    final provider = printerProvider ?? PrinterRegistry.active;

    if (template.printerId == null && template.printerName == null) {
      final error = PrinterUnavailableException(
        message: 'Template has no associated printer',
      );
      if (context != null && context.mounted) {
        await showPrinterUnavailableDialog(context, error);
      }
      throw error;
    }

    final printer = await provider.resolveAssociated(template);
    if (printer == null) {
      final error = PrinterUnavailableException(
        printerId: template.printerId,
        printerName: template.printerName,
        message: 'Associated printer is not available',
      );
      if (context != null && context.mounted) {
        await showPrinterUnavailableDialog(context, error);
      }
      throw error;
    }

    try {
      final bytes = await buildPdf(
        template: template,
        elements: elements,
        record: record,
        entityName: entityName,
        computedFields: computedFields,
      );
      await provider.printPdf(printer, bytes, jobName: template.name);
    } on PrinterUnavailableException catch (e) {
      if (context != null && context.mounted) {
        await showPrinterUnavailableDialog(context, e);
      }
      rethrow;
    }
  }

  // ── Batch — one page per record ─────────────────────────────────────────────

  /// Opens the OS print dialog with one page per record in [records].
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
