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
  /// Opens the OS print dialog for [template] filled with [record].
  ///
  /// [record] is a flat key→value map matching `{{namespace.field}}` tokens.
  /// [entityName] is the entity context used for token resolution.
  /// [computedFields] are formula-derived fields evaluated at print time.
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

  /// Builds and returns raw PDF bytes without showing any UI.
  ///
  /// Use this to upload, email, or store the PDF yourself.
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
}
