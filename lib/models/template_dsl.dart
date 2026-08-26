/// A terse declarative form for authoring templates.
///
/// Papercraft's storage format is a flat list of [CanvasElement]s with absolute
/// pixel coordinates — excellent for a drag-and-drop editor to write, miserable
/// for a human to author by hand. A host that ships default templates ends up
/// pasting hundreds of lines of coordinate JSON into a Dart string constant,
/// which nobody can review and which breaks the moment a font metric changes.
///
/// This compiles a nested row/column spec into that same element list:
///
/// ```dart
/// final elements = compileTemplate({
///   'col': [
///     {'row': [
///       {'text': '{{company.name}}', 'size': 20, 'weight': 'bold', 'flex': 3},
///       {'text': 'INVOICE', 'align': 'right', 'flex': 2},
///     ]},
///     {'rule': {}},
///     {'table': {'data': 'invoice.lines', 'columns': [...]}},
///   ],
/// }, idPrefix: 'invoice');
/// ```
///
/// **It compiles _to_ elements — it is not a parallel runtime format.** The
/// editor edits elements, storage stores elements, both renderers consume
/// elements. A spec interpreted at print time would be a second source of truth
/// the editor could not round-trip, and the first shop that nudged a margin in
/// the studio would silently fork from the default. Compiling is lossy — an
/// edited template cannot be decompiled — and that is correct: this is an
/// authoring tool for shipping defaults, not a storage format. Once compiled, a
/// default is indistinguishable from hand-drawn work and just as editable.
///
/// Two properties are guaranteed by construction, and both are load-bearing:
///
/// - **Flow-only.** No node is ever given `x`/`y`, and every direct child of
///   the root is a section. That is what lets `PrintService.buildPdf` choose
///   `pw.MultiPage`, so a long document paginates instead of clipping.
/// - **Deterministic ids.** Ids come from a depth-first counter, not from
///   [generateId] (which is `el_<millis>_<n>`). Compiling the same spec twice
///   yields byte-identical JSON, so a screenshot or golden test of a default
///   template does not churn on every run.
library;

import 'dart:convert';

import 'element_model.dart';
import 'table_element.dart';

// ── Palette ──────────────────────────────────────────────────────────────────

/// Defaults chosen so an unstyled spec still looks deliberate. Every one can be
/// overridden per node.
const String kInk = '#0F172A';
const String kMuted = '#64748B';
const String kHairline = '#E2E8F0';
const String kAccent = '#2563EB';
const String kTint = '#F1F5F9';
const String kSig = '#94A3B8';

// ── Compiler ─────────────────────────────────────────────────────────────────

/// Compiles [spec] into elements. [idPrefix] namespaces the generated ids.
List<CanvasElement> compileTemplate(
  Map<String, dynamic> spec, {
  required String idPrefix,
}) {
  final counter = _Counter(idPrefix);
  final root = spec.containsKey('col') || spec.containsKey('row')
      ? spec
      : <String, dynamic>{
          'col': [spec]
        };

  final children = (root['col'] ?? root['row']) as List;
  return [
    for (final child in children)
      _section(Map<String, dynamic>.from(child as Map), counter),
  ];
}

/// Compiles a top-level node into something that will actually flow.
///
/// `isSection` is a settable field on [ContainerElement] and [TableElement]
/// only — on every other element it is a hardcoded `false`. So a top-level
/// `text` or `rule` cannot mark itself as a section, and both renderers, which
/// draw the flow path from `where((e) => e.isSection)`, would silently drop it.
/// A heading that vanishes from the printed page is exactly the kind of failure
/// nobody notices until a customer does, so those get wrapped in a transparent
/// single-child section instead.
CanvasElement _section(Map<String, dynamic> node, _Counter ids) {
  final compiled = _compile(node, ids, section: true);
  if (compiled.isSection) return compiled;
  return ContainerElement(
    id: '${compiled.id}_s',
    type: 'col',
    isSection: true,
    gap: 0,
    padding: 0,
    minHeight: 0,
    alignItems: 'stretch',
    children: [compiled],
  );
}

/// [compileTemplate] over a JSON string.
List<CanvasElement> compileTemplateJson(
  String json, {
  required String idPrefix,
}) =>
    compileTemplate(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
      idPrefix: idPrefix,
    );

class _Counter {
  final String prefix;
  int _n = 0;
  _Counter(this.prefix);
  String next() => '${prefix}_${_n++}';
}

/// Compiles one node. [section] marks a top-level child, which flows.
CanvasElement _compile(
  Map<String, dynamic> node,
  _Counter ids, {
  bool section = false,
}) {
  final id = ids.next();

  if (node.containsKey('col') || node.containsKey('row')) {
    final isRow = node.containsKey('row');
    final kids = (node[isRow ? 'row' : 'col'] as List)
        .map((c) => _compile(Map<String, dynamic>.from(c as Map), ids))
        .toList();
    return ContainerElement(
      id: id,
      type: isRow ? 'row' : 'col',
      isSection: section,
      children: kids,
      gap: _d(node['gap']) ?? 6,
      padding: _d(node['padding']) ?? 0,
      paddingX: _d(node['padX']),
      paddingY: _d(node['padY']),
      // Rows centre their children by default (a label beside a value reads
      // wrong top-aligned); columns stretch so a right-aligned total can find
      // the full width to align against.
      alignItems: node['align'] as String? ?? (isRow ? 'center' : 'stretch'),
      background: node['background'] as String? ?? 'transparent',
      minHeight: _d(node['minHeight']) ?? 0,
      borderRadius: _d(node['radius']) ?? 0,
      flex: _flex(node),
    );
  }

  if (node.containsKey('text')) {
    return TextElement(
      id: id,
      content: node['text'] as String? ?? '',
      fontSize: _d(node['size']) ?? 9,
      fontWeight: node['weight'] as String? ?? 'normal',
      textAlign: node['textAlign'] as String? ?? 'left',
      color: node['color'] as String? ?? kInk,
      lineHeight: _d(node['lineHeight']) ?? 1.35,
      letterSpacing: _d(node['tracking']),
      flex: _flex(node),
      alignSelf: node['alignSelf'] as String?,
    );
  }

  // A small uppercase caption over a value — the field-label convention the
  // documents use throughout. Sugar for a text node, not a new element type.
  if (node.containsKey('label')) {
    return TextElement(
      id: id,
      content: (node['label'] as String? ?? '').toUpperCase(),
      fontSize: _d(node['size']) ?? 7,
      fontWeight: '600',
      color: node['color'] as String? ?? kMuted,
      letterSpacing: 0.4,
      lineHeight: 1.3,
      flex: _flex(node),
    );
  }

  if (node.containsKey('table')) {
    final t = Map<String, dynamic>.from(node['table'] as Map);
    t.putIfAbsent('padX', () => node['padX']);
    return _tableFrom(t, id: id, section: section, flex: _flex(node));
  }

  if (node.containsKey('qr')) {
    final size = _d(node['size']) ?? 64;
    return QrElement(
      id: id,
      content: node['qr'] as String? ?? '',
      width: size,
      height: size,
      flex: _flex(node),
      alignSelf: node['alignSelf'] as String?,
    );
  }

  if (node.containsKey('barcode')) {
    return BarcodeElement(
      id: id,
      content: node['barcode'] as String? ?? '',
      width: _d(node['width']) ?? 160,
      height: _d(node['height']) ?? 40,
      displayValue: node['displayValue'] as bool? ?? true,
      format: node['format'] as String? ?? 'CODE128',
      color: node['color'] as String? ?? '#000000',
      background: node['background'] as String? ?? '#ffffff',
      flex: _flex(node),
      alignSelf: node['alignSelf'] as String?,
    );
  }

  if (node.containsKey('image')) {
    return ImageElement(
      id: id,
      src: node['image'] as String? ?? '',
      width: _d(node['width']),
      height: _d(node['height']),
      objectFit: node['fit'] as String? ?? 'contain',
      flex: _flex(node),
      alignSelf: node['alignSelf'] as String?,
    );
  }

  // A hairline divider.
  if (node.containsKey('rule')) {
    final r = node['rule'] is Map
        ? Map<String, dynamic>.from(node['rule'] as Map)
        : <String, dynamic>{};
    // Stroke and radius are explicitly cleared. ShapeElement defaults to a
    // 1 px #1A1A1A stroke with a 4 px radius, so a "hairline" drawn without
    // them comes out as a dark rounded outline box — which is exactly what a
    // divider must not look like.
    return ShapeElement(
      id: id,
      shape: 'rectangle',
      fill: r['color'] as String? ?? kHairline,
      stroke: 'transparent',
      strokeWidth: 0,
      borderRadius: 0,
      height: _d(r['thickness']) ?? 1,
      flex: _flex(node),
    );
  }

  if (node.containsKey('spacer')) {
    final s = node['spacer'] is Map
        ? Map<String, dynamic>.from(node['spacer'] as Map)
        : <String, dynamic>{};
    return ShapeElement(
      id: id,
      shape: 'rectangle',
      fill: 'transparent',
      stroke: 'transparent',
      strokeWidth: 0,
      borderRadius: 0,
      height: _d(s['height']) ?? 8,
      flex: _flex(node),
    );
  }

  if (node.containsKey('shape')) {
    final s = node['shape'] is Map
        ? Map<String, dynamic>.from(node['shape'] as Map)
        : <String, dynamic>{};
    return ShapeElement(
      id: id,
      shape: s['kind'] as String? ?? 'rectangle',
      fill: s['fill'] as String? ?? 'transparent',
      stroke: s['stroke'] as String? ?? 'transparent',
      strokeWidth: _d(s['strokeWidth']) ?? 0,
      borderRadius: _d(s['radius']) ?? 0,
      width: _d(s['width']),
      height: _d(s['height']),
      flex: _flex(node),
      alignSelf: node['alignSelf'] as String?,
    );
  }

  // A host (or a converted template) may drop a raw element JSON object into
  // the spec — most importantly a `type: table` line-items node with
  // `rowSource` + `columns`. Compiling that as a first-class node, rather than
  // rejecting it, is what "respect the line-items JSON" means.
  if (node['type'] is String) {
    final copy = Map<String, dynamic>.from(node);
    copy.putIfAbsent('id', () => id);
    if (section) copy['isSection'] = true;
    // Flow-only: a pasted absolute table must not pin the whole document
    // back onto the single-page Stack path. The old left offset becomes
    // the flowing gutter so a RepairX `x: 40, width: 714` table still
    // sits in the letterhead margin.
    final x = copy.remove('x');
    copy.remove('y');
    if (section &&
        copy['paddingX'] == null &&
        x is num &&
        (copy['type'] == 'table')) {
      copy['paddingX'] = x;
    }
    return CanvasElement.fromJson(copy);
  }

  throw ArgumentError('Unknown DSL node: ${node.keys.join(', ')}');
}

/// Builds a [TableElement] from either the DSL shape (`data`, `size`) or the
/// element JSON shape (`rowSource`, `fontSize`, `headerColor`, …). Both must
/// produce the same painter inputs — a line-items table that looks right in
/// the spec and wrong on paper is the failure this exists to prevent.
TableElement _tableFrom(
  Map<String, dynamic> t, {
  required String id,
  required bool section,
  int? flex,
}) {
  return TableElement(
    id: t['id'] as String? ?? id,
    isSection: section,
    rowSource: t['data'] as String? ?? t['rowSource'] as String? ?? '',
    columnsFrom: t['columnsFrom'] as String? ?? '',
    columns: [
      for (final c in (t['columns'] as List? ?? const []))
        TableColumn.fromJson(Map<String, dynamic>.from(c as Map)),
    ],
    zebra: t['zebra'] as bool? ?? false,
    showHeader: t['showHeader'] as bool? ?? true,
    maxRows: t['maxRows'] as int? ?? 0,
    fontSize: _d(t['size'] ?? t['fontSize']) ?? 9,
    fontFamily: t['fontFamily'] as String? ?? 'Inter',
    color: t['color'] as String? ?? kInk,
    rowHeight: _d(t['rowHeight']) ?? 22,
    headerHeight: _d(t['headerHeight']) ?? 24,
    headerFontSize: _d(t['headerFontSize']) ?? 8,
    headerColor: t['headerColor'] as String? ?? kMuted,
    headerBackground: t['headerBackground'] as String? ?? kTint,
    gridColor: t['gridColor'] as String? ?? kHairline,
    gridWidth: _d(t['gridWidth']) ?? 0.5,
    zebraColor: t['zebraColor'] as String? ?? '#F8FAFC',
    cellPaddingX: _d(t['cellPaddingX']) ?? 6,
    paddingX: _d(t['padX'] ?? t['paddingX']) ?? 0,
    emptyText: t['emptyText'] as String? ?? 'No items.',
    flex: flex,
  );
}

int? _flex(Map<String, dynamic> node) {
  final v = node['flex'];
  if (v is int) return v;
  if (v is num) return v.round();
  return null;
}

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

// ── Dart sugar ───────────────────────────────────────────────────────────────
//
// Each returns the same map the compiler consumes, so there is exactly one
// compiler and the two surfaces cannot drift.

Map<String, dynamic> col(
  List<Map<String, dynamic>> children, {
  double? gap,
  double? padding,
  double? padX,
  double? padY,
  String? align,
  String? background,
  double? radius,
  double? minHeight,
  int? flex,
}) =>
    {
      'col': children,
      if (gap != null) 'gap': gap,
      if (padding != null) 'padding': padding,
      if (padX != null) 'padX': padX,
      if (padY != null) 'padY': padY,
      if (align != null) 'align': align,
      if (background != null) 'background': background,
      if (radius != null) 'radius': radius,
      if (minHeight != null) 'minHeight': minHeight,
      if (flex != null) 'flex': flex,
    };

Map<String, dynamic> row(
  List<Map<String, dynamic>> children, {
  double? gap,
  double? padding,
  double? padX,
  double? padY,
  String? align,
  String? background,
  double? radius,
  double? minHeight,
  int? flex,
}) =>
    {
      'row': children,
      if (gap != null) 'gap': gap,
      if (padding != null) 'padding': padding,
      if (padX != null) 'padX': padX,
      if (padY != null) 'padY': padY,
      if (align != null) 'align': align,
      if (background != null) 'background': background,
      if (radius != null) 'radius': radius,
      if (minHeight != null) 'minHeight': minHeight,
      if (flex != null) 'flex': flex,
    };

Map<String, dynamic> text(
  String content, {
  double? size,
  String? weight,
  String? textAlign,
  String? color,
  double? lineHeight,
  double? tracking,
  int? flex,
  String? alignSelf,
}) =>
    {
      'text': content,
      if (size != null) 'size': size,
      if (weight != null) 'weight': weight,
      if (textAlign != null) 'textAlign': textAlign,
      if (color != null) 'color': color,
      if (lineHeight != null) 'lineHeight': lineHeight,
      if (tracking != null) 'tracking': tracking,
      if (flex != null) 'flex': flex,
      if (alignSelf != null) 'alignSelf': alignSelf,
    };

/// A small uppercase field caption.
Map<String, dynamic> label(String content,
        {double? size, int? flex, String? color}) =>
    {
      'label': content,
      if (size != null) 'size': size,
      if (flex != null) 'flex': flex,
      if (color != null) 'color': color,
    };

/// A caption stacked over its value — the pattern every document header uses.
Map<String, dynamic> field(String caption, String value,
        {double? size, int? flex, String? sub, String? weight}) =>
    col([
      label(caption),
      text(value, size: size ?? 10, weight: weight ?? '600'),
      if (sub != null) text(sub, size: 8.5, color: kMuted, lineHeight: 1.4),
    ], gap: 1, flex: flex);

/// A label and a value on one line, the value right-aligned. The label hugs
/// (no flex) so the value takes the rest — which is what intrinsic row children
/// are for.
Map<String, dynamic> kv(String k, String v,
        {bool bold = false, double? size, String? color}) =>
    row([
      text(k, size: size ?? 9, color: color ?? kMuted),
      text(v,
          size: size ?? 9,
          weight: bold ? 'bold' : 'normal',
          textAlign: 'right',
          color: color ?? kInk,
          flex: 1),
    ], gap: 8);

/// Header meta: both sides right-aligned, the caption taking leftover width.
Map<String, dynamic> meta(String k, String v) => row([
      text(k, size: 8.5, color: kMuted, textAlign: 'right', flex: 1),
      text(v, size: 8.5, weight: '600', textAlign: 'right'),
    ], gap: 12);

/// Accent section title with a hairline under it.
Map<String, dynamic> heading(String title, {String? color}) => col([
      text(title.toUpperCase(),
          size: 8, weight: 'bold', color: color ?? kAccent, tracking: 0.9),
      rule(),
    ], gap: 3);

/// Full-bleed accent strip — the 6 px bar every A4 document starts with.
Map<String, dynamic> bar({String? color, double? height}) => {
      'shape': {
        'fill': color ?? kAccent,
        'height': height ?? 6,
      }
    };

Map<String, dynamic> shape({
  String kind = 'rectangle',
  String? fill,
  String? stroke,
  double? strokeWidth,
  double? radius,
  double? width,
  double? height,
  int? flex,
  String? alignSelf,
}) =>
    {
      'shape': {
        'kind': kind,
        if (fill != null) 'fill': fill,
        if (stroke != null) 'stroke': stroke,
        if (strokeWidth != null) 'strokeWidth': strokeWidth,
        if (radius != null) 'radius': radius,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      },
      if (flex != null) 'flex': flex,
      if (alignSelf != null) 'alignSelf': alignSelf,
    };

/// Empty checkbox + caption, for printed intake forms.
Map<String, dynamic> check(String caption, {int? flex}) => row([
      shape(
          width: 10,
          height: 10,
          fill: '#ffffff',
          stroke: kSig,
          strokeWidth: 1,
          radius: 2),
      text(caption, size: 8.5),
    ], gap: 6, flex: flex);

/// Signature line with a caption underneath.
Map<String, dynamic> sig(String caption, {int? flex}) => col([
      spacer(height: 28),
      rule(color: kSig),
      text(caption, size: 7, color: kMuted, tracking: 0.6),
    ], gap: 4, flex: flex);

Map<String, dynamic> table(
  String data, {
  List<TableColumn> columns = const [],
  String? columnsFrom,
  bool zebra = false,
  bool showHeader = true,
  int? maxRows,
  double? size,
  double? rowHeight,
  double? headerHeight,
  double? headerFontSize,
  String? headerColor,
  String? headerBackground,
  String? gridColor,
  double? gridWidth,
  String? zebraColor,
  double? cellPaddingX,
  double? padX,
  String? fontFamily,
  String? color,
  String? emptyText,
  int? flex,
}) =>
    {
      'table': {
        'data': data,
        'columns': [for (final c in columns) c.toJson()],
        if (columnsFrom != null) 'columnsFrom': columnsFrom,
        'zebra': zebra,
        'showHeader': showHeader,
        if (maxRows != null) 'maxRows': maxRows,
        if (size != null) 'size': size,
        if (rowHeight != null) 'rowHeight': rowHeight,
        if (headerHeight != null) 'headerHeight': headerHeight,
        if (headerFontSize != null) 'headerFontSize': headerFontSize,
        if (headerColor != null) 'headerColor': headerColor,
        if (headerBackground != null) 'headerBackground': headerBackground,
        if (gridColor != null) 'gridColor': gridColor,
        if (gridWidth != null) 'gridWidth': gridWidth,
        if (zebraColor != null) 'zebraColor': zebraColor,
        if (cellPaddingX != null) 'cellPaddingX': cellPaddingX,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (color != null) 'color': color,
        if (emptyText != null) 'emptyText': emptyText,
      },
      if (padX != null) 'padX': padX,
      if (flex != null) 'flex': flex,
    };

Map<String, dynamic> qr(String content,
        {double? size, int? flex, String? alignSelf}) =>
    {
      'qr': content,
      if (size != null) 'size': size,
      if (flex != null) 'flex': flex,
      if (alignSelf != null) 'alignSelf': alignSelf,
    };

Map<String, dynamic> barcode(String content,
        {double? width,
        double? height,
        bool? displayValue,
        String? format,
        String? color,
        String? background,
        int? flex}) =>
    {
      'barcode': content,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (displayValue != null) 'displayValue': displayValue,
      if (format != null) 'format': format,
      if (color != null) 'color': color,
      if (background != null) 'background': background,
      if (flex != null) 'flex': flex,
    };

Map<String, dynamic> image(String src,
        {double? width, double? height, String? fit, int? flex}) =>
    {
      'image': src,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (fit != null) 'fit': fit,
      if (flex != null) 'flex': flex,
    };

Map<String, dynamic> rule({String? color, double? thickness}) => {
      'rule': {
        if (color != null) 'color': color,
        if (thickness != null) 'thickness': thickness,
      }
    };

Map<String, dynamic> spacer({double? height, int? flex}) => {
      'spacer': {if (height != null) 'height': height},
      if (flex != null) 'flex': flex,
    };

// ── Guard ────────────────────────────────────────────────────────────────────

/// Throws when any element carries absolute coordinates.
///
/// The DSL cannot produce them, so this is a regression guard for hosts that
/// hand-assemble element lists and expect them to paginate — a stray `x`/`y`
/// silently drops the whole template back onto the single-page path, which
/// shows up as a clipped document rather than an error.
void assertFlowOnly(List<CanvasElement> elements) {
  for (final e in elements) {
    if (e.x != null || e.y != null) {
      throw StateError(
          'Element ${e.id} (${e.type}) has absolute coordinates; a flow-only '
          'template cannot paginate with absolutely positioned elements.');
    }
    if (!e.isSection) {
      throw StateError(
          'Top-level element ${e.id} (${e.type}) is not a section; it will '
          'not be drawn on the flow path.');
    }
  }
}
