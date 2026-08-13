/// Resolves a [TableElement] against a print record: which columns, which
/// rows, which strings in the cells.
///
/// Both painters — [PrintService] for the PDF and `ElementRenderer` for the
/// canvas — call [resolveTable] and then only *draw*. That is deliberate, and
/// it is the same tactic `flow_layout.dart` uses: the two renderers may differ
/// in painting primitives, never in what they computed. A table whose columns
/// resolved one way in the preview and another way in print would be the worst
/// possible version of this feature, because the difference only shows up on
/// paper.
library;

import 'table_element.dart';
import '../services/token_service.dart';

/// A table reduced to strings, ready to paint.
class ResolvedTable {
  final List<TableColumn> columns;

  /// Row-major cell text, already token-resolved. Always
  /// `cells[r].length == columns.length`.
  final List<List<String>> cells;

  /// `"+3 more"` when `maxRows` hid rows, else `null`. Painters must draw it —
  /// see [TableElement.overflowLabel] for why.
  final String? overflow;

  const ResolvedTable({
    required this.columns,
    required this.cells,
    this.overflow,
  });

  bool get isEmpty => cells.isEmpty;
}

/// Resolves [e] against [record].
///
/// Column resolution order:
/// 1. columns authored on the element;
/// 2. columns carried by the record under `columnsFrom` — for documents whose
///    columns are decided at print time (the generic report export, the bulk
///    list print);
/// 3. derived from the keys of the first row, with humanised headers, so a
///    table bound to nothing but a `rowSource` still renders sensibly.
ResolvedTable resolveTable(
  TableElement e,
  Map<String, dynamic>? record, {
  String? entityName,
  List<ComputedField> computedFields = const [],
}) {
  final rows = _rows(e, record);
  final columns = _columns(e, record, rows);

  final capped = e.maxRows > 0 && rows.length > e.maxRows
      ? rows.take(e.maxRows).toList()
      : rows;

  final cells = <List<String>>[];
  for (final row in capped) {
    cells.add([
      for (final col in columns)
        _cell(col, row, record, entityName, computedFields),
    ]);
  }

  return ResolvedTable(
    columns: columns,
    cells: cells,
    overflow: e.overflowLabel(rows.length),
  );
}

/// The bound rows, or empty when the key is missing or is not a list of maps.
List<Map<String, dynamic>> _rows(TableElement e, Map<String, dynamic>? record) {
  final raw = record?[e.rowSource];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();
}

List<TableColumn> _columns(
  TableElement e,
  Map<String, dynamic>? record,
  List<Map<String, dynamic>> rows,
) {
  if (e.columns.isNotEmpty) return e.columns;

  if (e.columnsFrom.isNotEmpty) {
    final raw = record?[e.columnsFrom];
    if (raw is List) {
      final fromRecord = raw
          .whereType<Map>()
          .map((m) => TableColumn.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (fromRecord.isNotEmpty) return fromRecord;
    }
  }

  if (rows.isEmpty) return const [];
  return rows.first.keys
      .map((k) => TableColumn(key: k, label: TableColumn.humanize(k)))
      .toList();
}

/// One cell's text.
///
/// A column key holding `{{` is a token expression resolved against the row
/// merged over the record, so a cell can reference both its own row and the
/// document (`"{{qty}} × {{invoice.currency}}"`). Anything else is a plain
/// lookup on the row.
String _cell(
  TableColumn col,
  Map<String, dynamic> row,
  Map<String, dynamic>? record,
  String? entityName,
  List<ComputedField> computedFields,
) {
  if (col.key.contains('{{')) {
    return TokenService.resolveTokens(
      col.key,
      {...?record, ...row},
      entityName,
      computedFields,
    );
  }
  return (row[col.key] ?? '').toString();
}

/// Pixel widths for [columns] across [totalWidth].
///
/// Fixed-width columns are taken out first; whatever remains is split by flex.
List<double> columnWidths(List<TableColumn> columns, double totalWidth) {
  if (columns.isEmpty) return const [];
  final fixed = columns.fold<double>(0, (a, c) => a + (c.width ?? 0));
  final flexTotal = columns
      .where((c) => c.width == null)
      .fold<double>(0, (a, c) => a + c.flex);
  final free = (totalWidth - fixed).clamp(0, double.infinity).toDouble();
  return columns
      .map((c) => c.width ?? (flexTotal == 0 ? 0.0 : free * c.flex / flexTotal))
      .toList();
}
