import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/element_model.dart';
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

// Returns the alignSelf value for any element type.
String? _childAlignSelf(CanvasElement c) => switch (c) {
      TextElement e => e.alignSelf,
      ShapeElement e => e.alignSelf,
      ImageElement e => e.alignSelf,
      QrElement e => e.alignSelf,
      BarcodeElement e => e.alignSelf,
      ContainerElement e => e.alignSelf,
      _ => null,
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

    final size = (e.width != null && e.height != null)
        ? [e.width!, e.height!].reduce((a, b) => a < b ? a : b).round()
        : 80;

    final url =
        'https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(resolved)}&size=${size}x$size&margin=0';

    return SizedBox(
      width: e.width ?? 80,
      height: e.height ?? 80,
      child: Opacity(
        opacity: e.opacity,
        child: Image.network(url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
              Container(color: AppColors.secondary,
                child: const Icon(Icons.qr_code, color: AppColors.mutedForeground))),
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
      // Each child shares available width via Expanded (flex weight).
      // alignSelf on each child controls its vertical position within the row.
      // CrossAxisAlignment.start lets children control their own alignment.
      if (e.children.isEmpty) {
        content = _emptySlot();
      } else {
        final kids = <Widget>[];
        for (int i = 0; i < e.children.length; i++) {
          if (i > 0) kids.add(SizedBox(width: e.gap));
          final c = e.children[i];
          final flex = _childFlex(c) > 0 ? _childFlex(c) : 1;
          final renderer = ElementRenderer(
              el: c, record: record, entityName: entityName, computedFields: computedFields);
          kids.add(Expanded(
            flex: flex,
            child: _wrapAlignSelfRow(c, renderer),
          ));
        }
        final row = Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: kids,
        );
        // Section rows have no fixed height (isSection→height:null). Wrap
        // with IntrinsicHeight so the Row's cross-axis becomes the maximum
        // natural height of its children instead of being unbounded.
        content = e.isSection ? IntrinsicHeight(child: row) : row;
      }
    } else {
      // ── Column mode ──────────────────────────────────────────────────────────
      // alignSelf on each child controls its horizontal position within the col.
      // CrossAxisAlignment.start lets children control their own alignment.
      if (e.children.isEmpty) {
        content = _emptySlot();
      } else {
        final kids = <Widget>[];
        for (int i = 0; i < e.children.length; i++) {
          if (i > 0) kids.add(SizedBox(height: e.gap));
          final c = e.children[i];
          final renderer = ElementRenderer(
              el: c, record: record, entityName: entityName, computedFields: computedFields);
          kids.add(SizedBox(
            height: c.height,
            child: _wrapAlignSelfCol(c, renderer),
          ));
        }
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
          padding: EdgeInsets.all(e.padding),
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

  int _childFlex(CanvasElement c) {
    if (c is TextElement) return c.flex ?? 0;
    if (c is ShapeElement) return c.flex ?? 0;
    if (c is ImageElement) return c.flex ?? 0;
    if (c is QrElement) return c.flex ?? 0;
    if (c is BarcodeElement) return c.flex ?? 0;
    if (c is ContainerElement) return c.flex ?? 0;
    return 0;
  }

  BoxFit _boxFit(String fit) => switch (fit) {
        'contain' => BoxFit.contain,
        'fill' => BoxFit.fill,
        'none' => BoxFit.none,
        _ => BoxFit.cover,
      };
}
