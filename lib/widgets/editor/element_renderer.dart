import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/element_model.dart';
import '../../models/flow_layout.dart';
import '../../models/table_layout.dart';
import '../../models/gradient_def.dart';
import '../../services/token_service.dart';
import '../../theme/app_colors.dart';
import 'barcode_painter.dart';

Color hexToFlutter(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return Colors.black;
  }
}

FontWeight parseFontWeight(String w) {
  return switch (w) {
    '300' => FontWeight.w300,
    'normal' || '400' => FontWeight.normal,
    '500' => FontWeight.w500,
    '600' => FontWeight.w600,
    'bold' || '700' => FontWeight.bold,
    '800' => FontWeight.w800,
    _ => FontWeight.normal,
  };
}

TextAlign parseTextAlign(String a) {
  return switch (a) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    'justify' => TextAlign.justify,
    _ => TextAlign.left,
  };
}

TextDecoration _parseTextDecoration(String? d) => switch (d) {
      'underline' => TextDecoration.underline,
      'lineThrough' => TextDecoration.lineThrough,
      'overline' => TextDecoration.overline,
      _ => TextDecoration.none,
    };

TextStyle textStyleFrom(TextElement el) {
  return GoogleFonts.getFont(
    _safeFontFamily(el.fontFamily),
    fontSize: el.fontSize,
    fontWeight: parseFontWeight(el.fontWeight),
    fontStyle: el.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
    color: el.textGradient != null ? Colors.transparent : hexToFlutter(el.color),
    height: el.lineHeight,
    letterSpacing: el.letterSpacing,
    decoration: el.textDecoration != null ? _parseTextDecoration(el.textDecoration) : null,
  );
}

String _safeFontFamily(String family) {
  const googleFonts = {'Inter', 'Playfair Display', 'Lora', 'DM Mono'};
  return googleFonts.contains(family) ? family : 'Inter';
}

// Parses CSS box-shadow string (e.g. "0 4px 12px rgba(0,0,0,0.12), 0 2px 4px rgba(0,0,0,0.08)")
// into a list of Flutter BoxShadow objects.
List<BoxShadow>? parseBoxShadow(String? css) {
  if (css == null || css.isEmpty) return null;
  try {
    final parts = css.split(RegExp(r',\s*(?=[\d-])'));
    return parts.map((s) {
      final rgbaMatch = RegExp(
        r'rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)',
      ).firstMatch(s);
      final noRgba = s.replaceAll(RegExp(r'rgba\(.*?\)'), '');
      final nums = RegExp(r'-?[\d.]+').allMatches(noRgba).toList();
      final dx = nums.isNotEmpty ? double.tryParse(nums[0].group(0)!) ?? 0.0 : 0.0;
      final dy = nums.length > 1 ? double.tryParse(nums[1].group(0)!) ?? 0.0 : 0.0;
      final blur = nums.length > 2 ? double.tryParse(nums[2].group(0)!) ?? 0.0 : 0.0;
      Color color = const Color(0x1A000000);
      if (rgbaMatch != null) {
        color = Color.fromRGBO(
          int.parse(rgbaMatch.group(1)!),
          int.parse(rgbaMatch.group(2)!),
          int.parse(rgbaMatch.group(3)!),
          double.parse(rgbaMatch.group(4)!),
        );
      }
      return BoxShadow(color: color, offset: Offset(dx, dy), blurRadius: blur);
    }).toList();
  } catch (_) {
    return null;
  }
}

// Returns the alignSelf value for any element type. Delegates to
// flow_layout.dart so a newly added element type cannot be forgotten here and
// silently lose its alignment — which is exactly how the PDF's flex helper
// came to omit QR and barcode.
String? _childAlignSelf(CanvasElement c) => switch (c) {
      _ => alignSelfOf(c),
    };

// Wraps a Row child to respect its alignSelf (cross-axis = vertical in a Row).
// NOTE: We avoid SizedBox(height: ∞) because section Rows have an unbounded
// cross-axis, which would crash layout. We use Align only when the child has
// an explicit height (i.e., bounded cross-axis is guaranteed); otherwise we
// just return the child and let it size itself naturally.
Widget _wrapAlignSelfRow(CanvasElement c, Widget child) {
  final as_ = _childAlignSelf(c);
  if (as_ == null || as_ == 'auto' || as_ == 'stretch') {
    return child; // natural height; Row cross-axis may be unbounded in sections
  }
  // For explicit alignment, wrap only if the child has a known height so
  // Align has bounded constraints to work with.
  final hasHeight = c.height != null && c.height! > 0;
  if (!hasHeight) return child;
  return Align(
    heightFactor: 1,
    alignment: switch (as_) {
      'flex-start' => Alignment.topLeft,
      'center' => Alignment.centerLeft,
      'flex-end' => Alignment.bottomLeft,
      _ => Alignment.topLeft,
    },
    child: child,
  );
}

// Wraps a Col child to respect its alignSelf (cross-axis = horizontal in a Col).
Widget _wrapAlignSelfCol(CanvasElement c, Widget child) {
  final as_ = _childAlignSelf(c);
  // Col cross-axis (horizontal) is bounded when inside canvas / Positioned.
  // SizedBox(width:∞) = "stretch to available width" which is fine here.
  if (as_ == null || as_ == 'auto' || as_ == 'stretch') {
    return child;
  }
  return Align(
    widthFactor: 1,
    alignment: switch (as_) {
      'flex-start' => Alignment.topLeft,
      'center' => Alignment.topCenter,
      'flex-end' => Alignment.topRight,
      _ => Alignment.topLeft,
    },
    child: child,
  );
}

// ── Element widget for preview / canvas (read-only rendering) ────────────────

class ElementRenderer extends StatelessWidget {
  final CanvasElement el;
  final Map<String, dynamic>? record;
  final String? entityName;
  final List<ComputedField> computedFields;
  final bool showTokenChips; // false in preview/export

  const ElementRenderer({
    super.key,
    required this.el,
    this.record,
    this.entityName,
    this.computedFields = const [],
    this.showTokenChips = false,
  });

  @override
  Widget build(BuildContext context) {
    return switch (el) {
      TextElement e => _renderText(e),
      ShapeElement e => _renderShape(e),
      ImageElement e => _renderImage(e),
      QrElement e => _renderQr(e),
      BarcodeElement e => _renderBarcode(e),
      ContainerElement e => _renderContainer(e),
      TableElement e => _renderTable(e),
      _ => const SizedBox(),
    };
  }

  Widget _renderText(TextElement e) {
    // Edit mode: render {{tokens}} as accent-colored chip pills
    if (record == null && showTokenChips && e.content.contains('{{')) {
      return SizedBox(
        width: e.width,
        height: e.height,
        child: Opacity(
          opacity: e.opacity,
          child: _buildChipText(e),
        ),
      );
    }

    final resolved = record != null
        ? TokenService.resolveTokens(
            e.content, record, entityName, computedFields)
        : e.content;

    final style = textStyleFrom(e);

    Widget text = Text(
      resolved,
      style: style,
      textAlign: parseTextAlign(e.textAlign),
    );

    if (e.textGradient != null) {
      text = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) =>
            e.textGradient!.toFlutter().createShader(bounds),
        child: text,
      );
    }

    return SizedBox(
      width: e.width,
      height: e.height,
      child: Opacity(
        opacity: e.opacity,
        child: text,
      ),
    );
  }

  Widget _buildChipText(TextElement e) {
    final regex = RegExp(r'\{\{(.*?)\}\}');
    final spans = <InlineSpan>[];
    int last = 0;
    final content = e.content;
    final baseStyle = textStyleFrom(e);

    for (final match in regex.allMatches(content)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: content.substring(last, match.start),
          style: baseStyle,
        ));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: withAlpha(AppColors.accent, 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: withAlpha(AppColors.accent, 0.25), width: 1),
          ),
          child: Text(
            '{{${match.group(1)}}}',
            style: TextStyle(
              fontSize: (e.fontSize * 0.82).clamp(8.0, 16.0),
              color: AppColors.accent,
              fontFamily: 'monospace',
              height: 1.0,
            ),
          ),
        ),
      ));
      last = match.end;
    }

    if (last < content.length) {
      spans.add(TextSpan(text: content.substring(last), style: baseStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: parseTextAlign(e.textAlign),
    );
  }

  Widget _renderShape(ShapeElement e) {
    final isCircle = e.shape == 'circle';
    final isLine = e.shape == 'line';

    BoxDecoration decoration;
    if (isLine) {
      decoration = BoxDecoration(
        color: hexToFlutter(e.fill == 'transparent' ? '#00000000' : e.fill),
      );
    } else {
      decoration = BoxDecoration(
        gradient: e.gradient?.toFlutter(),
        color: e.gradient == null
            ? (e.fill == 'transparent'
                ? Colors.transparent
                : hexToFlutter(e.fill))
            : null,
        border: Border.all(
            color: hexToFlutter(e.stroke), width: e.strokeWidth),
        borderRadius: isCircle
            ? BorderRadius.circular(10000)
            : e.corners.toBorderRadius(),
        boxShadow: parseBoxShadow(e.boxShadow),
      );
    }

    return SizedBox(
      width: e.width ?? 120,
      height: e.height ?? 80,
      child: Opacity(
        opacity: e.opacity,
        child: Container(decoration: decoration),
      ),
    );
  }

  Widget _renderImage(ImageElement e) {
    final radius = e.corners.toBorderRadius();
    if (e.src.isEmpty) {
      return SizedBox(
        width: e.width ?? 150,
        height: e.height ?? 100,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondary,
            border: Border.all(
                color: AppColors.border, width: 1.5,
                style: BorderStyle.solid),
            borderRadius: radius,
          ),
          child: const Center(
            child: Text('Image',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground)),
          ),
        ),
      );
    }
    return SizedBox(
      width: e.width ?? 150,
      height: e.height ?? 100,
      child: Opacity(
        opacity: e.opacity,
        child: ClipRRect(
          borderRadius: radius,
          child: Image.network(e.src,
              fit: _boxFit(e.objectFit), errorBuilder: (_, __, ___) =>
                Container(color: AppColors.secondary,
                  child: const Icon(Icons.broken_image, color: AppColors.mutedForeground))),
        ),
      ),
    );
  }

  Widget _renderQr(QrElement e) {
    final resolved = record != null
        ? TokenService.resolveTokens(
            e.content, record, entityName, computedFields)
        : e.content;

    // Painted locally from the same encoder the PDF uses, rather than fetched
    // as a PNG from api.qrserver.com. The old path meant a designer with no
    // internet saw a placeholder icon, a shop with no internet PRINTED a grey
    // box in place of a scannable code, and every label in the product
    // depended on a third-party service staying up.
    return SizedBox(
      width: e.width ?? 80,
      height: e.height ?? 80,
      child: Opacity(
        opacity: e.opacity,
        child: CustomPaint(
          painter: QrPainter(data: resolved, color: Colors.black),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _renderBarcode(BarcodeElement e) {
    final resolved = record != null
        ? TokenService.resolveTokens(
            e.content, record, entityName, computedFields)
        : e.content;

    final effective = e.copyWith(content: resolved);

    return SizedBox(
      width: e.width ?? 200,
      height: e.height ?? 80,
      child: Opacity(
        opacity: e.opacity,
        child: CustomPaint(
          painter: BarcodePainter(effective),
          size: Size(e.width ?? 200, e.height ?? 80),
        ),
      ),
    );
  }

  Widget _renderContainer(ContainerElement e) {
    final isRow = e.type == 'row';
    final decoration = BoxDecoration(
      gradient: e.gradient?.toFlutter(),
      color: e.gradient == null
          ? (e.background == 'transparent'
              ? Colors.transparent
              : hexToFlutter(e.background))
          : null,
      borderRadius: e.corners.toBorderRadius(),
      boxShadow: parseBoxShadow(e.boxShadow),
    );

    Widget content;

    if (e.freePlacement) {
      // ── Free / Stack mode ────────────────────────────────────────────────────
      content = e.children.isEmpty
          ? _emptySlot()
          : Stack(
              clipBehavior: Clip.none,
              children: e.children.map((c) {
                final child = ElementRenderer(
                    el: c, record: record, entityName: entityName, computedFields: computedFields);
                if (c.x != null && c.y != null) {
                  return Positioned(left: c.x!, top: c.y!, child: child);
                }
                return child;
              }).toList(),
            );
    } else if (isRow) {
      // ── Row mode ─────────────────────────────────────────────────────────────
      // Layout decisions come from `slotFor` so this and the PDF painter in
      // print_service.dart cannot disagree — see models/flow_layout.dart.
      if (e.children.isEmpty) {
        content = _emptySlot();
      } else {
        final kids = <Widget>[];
        for (int i = 0; i < e.children.length; i++) {
          if (i > 0) kids.add(SizedBox(width: e.gap));
          final c = e.children[i];
          final slot = slotFor(e, c);
          final renderer = ElementRenderer(
              el: c, record: record, entityName: entityName, computedFields: computedFields);
          final child = _wrapAlignSelfRow(c, renderer);
          kids.add(slot.expand
              ? Expanded(flex: slot.flex, child: child)
              : SizedBox(height: slot.fixedHeight, child: child));
        }
        final row = Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: _crossAxis(containerAlign(e)),
          children: kids,
        );
        // Section rows have no fixed height (isSection→height:null). Wrap
        // with IntrinsicHeight so the Row's cross-axis becomes the maximum
        // natural height of its children instead of being unbounded.
        content = e.isSection ? IntrinsicHeight(child: row) : row;
      }
    } else {
      // ── Column mode ──────────────────────────────────────────────────────────
      // alignSelf on each child controls its horizontal position within the col;
      // the container's own alignItems sets the default. Same `slotFor` the PDF
      // painter uses.
      if (e.children.isEmpty) {
        content = _emptySlot();
      } else {
        final kids = <Widget>[];
        for (int i = 0; i < e.children.length; i++) {
          if (i > 0) kids.add(SizedBox(height: e.gap));
          final c = e.children[i];
          final slot = slotFor(e, c);
          final renderer = ElementRenderer(
              el: c, record: record, entityName: entityName, computedFields: computedFields);
          kids.add(SizedBox(
            width: slot.stretchWidth ? double.infinity : null,
            height: slot.fixedHeight,
            child: _wrapAlignSelfCol(c, renderer),
          ));
        }
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _crossAxis(containerAlign(e)),
          children: kids,
        );
      }
    }

    return SizedBox(
      width: e.isSection ? double.infinity : e.width,
      height: e.isSection ? null : e.height,
      child: Opacity(
        opacity: e.opacity,
        child: Container(
          decoration: decoration,
          padding: EdgeInsets.symmetric(
              horizontal: e.padX, vertical: e.padY),
          child: content,
        ),
      ),
    );
  }

  Widget _emptySlot() => Container(
        color: withAlpha(AppColors.foreground, 0.03),
        child: Center(
          child: Text('Empty',
              style: TextStyle(
                  fontSize: 10,
                  color: withAlpha(AppColors.foreground, 0.22))),
        ),
      );

  /// Table — the canvas twin of `PrintService._renderTable`.
  ///
  /// Both call [resolveTable] and then only draw, so the columns and cell text
  /// a designer sees here are by construction the ones that print.
  ///
  /// With no bound record (the editor, before a sample record is picked) the
  /// resolver yields no rows, so placeholder rows are drawn instead — a table
  /// showing nothing but a header gives the designer no sense of its height.
  Widget _renderTable(TableElement e) {
    final t = resolveTable(e, record,
        entityName: entityName, computedFields: computedFields);

    final columns = t.columns.isNotEmpty
        ? t.columns
        : const [
            TableColumn(key: 'column', label: 'Column'),
            TableColumn(key: 'value', label: 'Value', align: 'right'),
          ];
    final showPlaceholders = t.isEmpty && record == null;
    final cells = showPlaceholders
        ? [
            for (var r = 0; r < 3; r++)
              [for (final c in columns) '{{${e.rowSource}[].${c.key}}}'],
          ]
        : t.cells;

    final grid = BorderSide(
        color: hexToFlutter(e.gridColor),
        width: e.gridWidth);

    Widget cell(String text, TableColumn col, {required bool header}) => Container(
          height: header ? e.headerHeight : e.rowHeight,
          alignment: switch (col.align) {
            'right' => Alignment.centerRight,
            'center' => Alignment.center,
            _ => Alignment.centerLeft,
          },
          padding: EdgeInsets.symmetric(horizontal: e.cellPaddingX),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: header ? e.headerFontSize : e.fontSize,
              fontWeight: header ? FontWeight.w600 : FontWeight.w400,
              fontStyle: showPlaceholders ? FontStyle.italic : FontStyle.normal,
              color:
                  header ? hexToFlutter(e.headerColor) : hexToFlutter(e.color),
            ),
          ),
        );

    if (t.columns.isEmpty && !showPlaceholders) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: e.cellPaddingX, vertical: 6),
        child: Text(e.emptyText,
            style: TextStyle(
                fontSize: e.fontSize,
                color: hexToFlutter(e.headerColor))),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: {
            for (var i = 0; i < columns.length; i++)
              i: columns[i].width != null
                  ? FixedColumnWidth(columns[i].width!)
                  : FlexColumnWidth(columns[i].flex),
          },
          children: [
            if (e.showHeader)
              TableRow(
                decoration: BoxDecoration(
                  color: hexToFlutter(e.headerBackground),
                  border: Border(bottom: grid),
                ),
                children: [
                  for (final col in columns)
                    cell(
                        record != null
                            ? TokenService.resolveTokens(col.label, record,
                                entityName, computedFields)
                            : col.label,
                        col,
                        header: true),
                ],
              ),
            for (var r = 0; r < cells.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: e.zebra && r.isOdd
                      ? hexToFlutter(e.zebraColor)
                      : null,
                  border: Border(bottom: grid),
                ),
                children: [
                  for (var c = 0; c < columns.length; c++)
                    cell(c < cells[r].length ? cells[r][c] : '', columns[c],
                        header: false),
                ],
              ),
          ],
        ),
        if (t.overflow != null)
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: e.cellPaddingX, vertical: 4),
            child: Text(t.overflow!,
                style: TextStyle(
                    fontSize: e.fontSize,
                    fontStyle: FontStyle.italic,
                    color: hexToFlutter(e.headerColor) ??
                        const Color(0xFF64748B))),
          ),
      ],
    );
  }

  CrossAxisAlignment _crossAxis(FlowAlign a) => switch (a) {
        FlowAlign.start => CrossAxisAlignment.start,
        FlowAlign.center => CrossAxisAlignment.center,
        FlowAlign.end => CrossAxisAlignment.end,
        FlowAlign.stretch => CrossAxisAlignment.stretch,
      };

  BoxFit _boxFit(String fit) => switch (fit) {
        'contain' => BoxFit.contain,
        'fill' => BoxFit.fill,
        'none' => BoxFit.none,
        _ => BoxFit.cover,
      };
}
