import '../services/token_service.dart';

/// Describes a live data record to drive token substitution in the canvas.
///
/// Pass this to [PapercraftEditor] or [PapercraftRenderer] to fill
/// `{{namespace.field}}` tokens with real values at runtime.
///
/// ```dart
/// PapercraftEditor(
///   templateId: id,
///   dataSource: PapercraftDataSource(
///     entityName: 'work_order',
///     fields: {
///       'work_order.number':   'WO-4821',
///       'customer.name':       'Jane Doe',
///       'device.model':        'iPhone 15',
///       'repair.description':  'Cracked screen',
///     },
///     computedFields: [
///       ComputedField(name: 'vat_total', formula: 'price * 1.21'),
///     ],
///   ),
/// )
/// ```
///
/// Keys in [fields] must use the `namespace.field` convention to match
/// `{{namespace.field}}` tokens on the canvas.
class PapercraftDataSource {
  /// Entity name context (e.g. `'work_order'`, `'shipment'`).
  final String entityName;

  /// Flat map of field values. Keys must match the `namespace.field` token
  /// convention used in text elements (e.g. `'customer.name'`).
  final Map<String, dynamic> fields;

  /// Optional formula-derived fields evaluated at render/print time.
  final List<ComputedField> computedFields;

  const PapercraftDataSource({
    required this.entityName,
    required this.fields,
    this.computedFields = const [],
  });
}

/// Controls which mode [PapercraftEditor] starts in.
enum PapercraftMode {
  /// Full editor with toolbar, sidebars, canvas handles (default).
  edit,

  /// Read-only canvas render — no editor chrome, no handles.
  /// The editor chrome is hidden; only the filled canvas is shown.
  preview,

  /// Opens directly into the print-preview dialog.
  /// Useful for a "print this record" flow without showing the editor.
  printReady,
}
