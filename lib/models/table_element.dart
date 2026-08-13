/// The line-items element.
///
/// Every repair document with priced work — invoice, estimate, insurance cost
/// estimate, receipt — is a repeating row list, and until this existed
/// Papercraft could only fake one as a pre-joined multiline `text`, which
/// loses column alignment and cannot right-align an amount.
///
/// A table binds to a **list on the print record**, under [TableElement.rowSource]
/// (`record['invoice.lines']`), so row data arrives through the same map the
/// `{{tokens}}` already come from. No change to `Template`, storage, or the
/// token contract.
///
/// It is the one non-container element with a settable `isSection`: a table is
/// usually the tall, growing part of a document, so it has to be able to flow
/// down the page and paginate rather than sit at a fixed `y`.
library;

import 'element_model.dart';

/// One column of a [TableElement].
class TableColumn {
  /// Key looked up on each row map. May instead be a `{{token}}` expression,
  /// in which case it is resolved against the row merged over the record.
  final String key;

  /// Header text. Tokens are allowed.
  final String label;

  /// Share of the table's width, distributed against the other columns' flex.
  /// Ignored when [width] is set.
  final double flex;

  /// Fixed width in px. Wins over [flex] when set.
  final double? width;

  /// `left` | `center` | `right`.
  final String align;

  const TableColumn({
    required this.key,
    this.label = '',
    this.flex = 1,
    this.width,
    this.align = 'left',
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'flex': flex,
        if (width != null) 'width': width,
        'align': align,
      };

  factory TableColumn.fromJson(Map<String, dynamic> j) => TableColumn(
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        flex: (j['flex'] as num? ?? 1).toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        align: j['align'] as String? ?? 'left',
      );

  /// Title-cases a bare row key for use as a header when no label was authored
  /// — `unit_price` becomes `Unit Price`. This is what makes a table dropped on
  /// a canvas with nothing but a `rowSource` still look deliberate.
  static String humanize(String key) => key
      .split(RegExp(r'[_\s.]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class TableElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type = 'table';
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;

  /// Kept for interface compatibility. A table's drawn height is derived from
  /// its row count — see [resolvedHeight] — not from this.
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;

  /// Unlike every other leaf element, a table can flow. See the library note.
  @override
  final bool isSection;

  /// Record key holding the rows: `record['invoice.lines']`.
  final String rowSource;

  /// Record key holding column definitions, for documents whose columns are
  /// not known when the template is authored — the generic report export and
  /// the bulk list print. Ignored when [columns] is non-empty.
  final String columnsFrom;

  /// Authored columns. When empty, columns are taken from [columnsFrom], and
  /// failing that derived from the keys of the first row.
  final List<TableColumn> columns;

  final double headerHeight;
  final double rowHeight;

  /// Row cap. `0` means no cap, which is the default: a table that flows
  /// paginates instead of dropping rows. When set, the overflow is **stated**
  /// rather than silent — see [overflowLabel].
  final int maxRows;

  final bool showHeader;
  final double fontSize;
  final String fontFamily;
  final String color;
  final double headerFontSize;
  final String headerColor;
  final String headerBackground;
  final String gridColor;
  final double gridWidth;
  final bool zebra;
  final String zebraColor;
  final double cellPaddingX;

  /// Drawn when the bound list is missing or empty.
  final String emptyText;

  final int? flex;
  final String? alignSelf;

  const TableElement({
    required this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.isSection = false,
    this.rowSource = '',
    this.columnsFrom = '',
    this.columns = const [],
    this.headerHeight = 24,
    this.rowHeight = 22,
    this.maxRows = 0,
    this.showHeader = true,
    this.fontSize = 9,
    this.fontFamily = 'Inter',
    this.color = '#0F172A',
    this.headerFontSize = 8,
    this.headerColor = '#64748B',
    this.headerBackground = '#F1F5F9',
    this.gridColor = '#E2E8F0',
    this.gridWidth = 0.5,
    this.zebra = false,
    this.zebraColor = '#F8FAFC',
    this.cellPaddingX = 6,
    this.emptyText = 'No items.',
    this.flex,
    this.alignSelf,
  });

  static TableElement create() => TableElement(
        id: generateId(),
        x: 40,
        y: 40,
        width: 500,
        rowSource: 'items',
        columns: const [
          TableColumn(key: 'description', label: 'Description', flex: 4),
          TableColumn(key: 'qty', label: 'Qty', flex: 1, align: 'right'),
          TableColumn(key: 'amount', label: 'Amount', flex: 2, align: 'right'),
        ],
      );

  static TableElement createChild() => TableElement(
        id: generateId(),
        isSection: false,
        rowSource: 'items',
        columns: const [
          TableColumn(key: 'description', label: 'Description', flex: 4),
          TableColumn(key: 'qty', label: 'Qty', flex: 1, align: 'right'),
          TableColumn(key: 'amount', label: 'Amount', flex: 2, align: 'right'),
        ],
      );

  /// Drawn height for [rowCount] rows, for the editor's selection box.
  double resolvedHeight(int rowCount) {
    final shown = maxRows > 0 ? rowCount.clamp(0, maxRows) : rowCount;
    return (showHeader ? headerHeight : 0) + rowHeight * shown;
  }

  /// `"+3 more"` when [maxRows] hid rows, else `null`.
  ///
  /// A clipped table that says nothing reads as a complete one, and an invoice
  /// that quietly loses its last four lines is worse than one that runs long.
  String? overflowLabel(int rowCount) {
    if (maxRows <= 0 || rowCount <= maxRows) return null;
    return '+${rowCount - maxRows} more';
  }

  TableElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isSection,
    String? rowSource,
    String? columnsFrom,
    List<TableColumn>? columns,
    double? headerHeight,
    double? rowHeight,
    int? maxRows,
    bool? showHeader,
    double? fontSize,
    String? fontFamily,
    String? color,
    double? headerFontSize,
    String? headerColor,
    String? headerBackground,
    String? gridColor,
    double? gridWidth,
    bool? zebra,
    String? zebraColor,
    double? cellPaddingX,
    String? emptyText,
    int? flex,
    String? alignSelf,
  }) =>
      TableElement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        isSection: isSection ?? this.isSection,
        rowSource: rowSource ?? this.rowSource,
        columnsFrom: columnsFrom ?? this.columnsFrom,
        columns: columns ?? this.columns,
        headerHeight: headerHeight ?? this.headerHeight,
        rowHeight: rowHeight ?? this.rowHeight,
        maxRows: maxRows ?? this.maxRows,
        showHeader: showHeader ?? this.showHeader,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        color: color ?? this.color,
        headerFontSize: headerFontSize ?? this.headerFontSize,
        headerColor: headerColor ?? this.headerColor,
        headerBackground: headerBackground ?? this.headerBackground,
        gridColor: gridColor ?? this.gridColor,
        gridWidth: gridWidth ?? this.gridWidth,
        zebra: zebra ?? this.zebra,
        zebraColor: zebraColor ?? this.zebraColor,
        cellPaddingX: cellPaddingX ?? this.cellPaddingX,
        emptyText: emptyText ?? this.emptyText,
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'isSection': isSection,
        'rowSource': rowSource,
        if (columnsFrom.isNotEmpty) 'columnsFrom': columnsFrom,
        'columns': columns.map((c) => c.toJson()).toList(),
        'headerHeight': headerHeight,
        'rowHeight': rowHeight,
        'maxRows': maxRows,
        'showHeader': showHeader,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'color': color,
        'headerFontSize': headerFontSize,
        'headerColor': headerColor,
        'headerBackground': headerBackground,
        'gridColor': gridColor,
        'gridWidth': gridWidth,
        'zebra': zebra,
        'zebraColor': zebraColor,
        'cellPaddingX': cellPaddingX,
        'emptyText': emptyText,
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory TableElement.fromJson(Map<String, dynamic> j) => TableElement(
        id: j['id'] as String,
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        rotation: (j['rotation'] as num? ?? 0).toDouble(),
        opacity: (j['opacity'] as num? ?? 1).toDouble(),
        zIndex: (j['zIndex'] as int? ?? 1),
        isSection: j['isSection'] as bool? ?? false,
        rowSource: j['rowSource'] as String? ?? '',
        columnsFrom: j['columnsFrom'] as String? ?? '',
        columns: (j['columns'] as List? ?? const [])
            .map((c) => TableColumn.fromJson(
                Map<String, dynamic>.from(c as Map)))
            .toList(),
        headerHeight: (j['headerHeight'] as num? ?? 24).toDouble(),
        rowHeight: (j['rowHeight'] as num? ?? 22).toDouble(),
        maxRows: j['maxRows'] as int? ?? 0,
        showHeader: j['showHeader'] as bool? ?? true,
        fontSize: (j['fontSize'] as num? ?? 9).toDouble(),
        fontFamily: j['fontFamily'] as String? ?? 'Inter',
        color: j['color'] as String? ?? '#0F172A',
        headerFontSize: (j['headerFontSize'] as num? ?? 8).toDouble(),
        headerColor: j['headerColor'] as String? ?? '#64748B',
        headerBackground: j['headerBackground'] as String? ?? '#F1F5F9',
        gridColor: j['gridColor'] as String? ?? '#E2E8F0',
        gridWidth: (j['gridWidth'] as num? ?? 0.5).toDouble(),
        zebra: j['zebra'] as bool? ?? false,
        zebraColor: j['zebraColor'] as String? ?? '#F8FAFC',
        cellPaddingX: (j['cellPaddingX'] as num? ?? 6).toDouble(),
        emptyText: j['emptyText'] as String? ?? 'No items.',
        flex: j['flex'] as int?,
        alignSelf: j['alignSelf'] as String?,
      );
}
