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

TextStyle textStyleFrom(TextElement el) {
  final textStyle = GoogleFonts.getFont(
    _safeFontFamily(el.fontFamily),
    fontSize: el.fontSize,
    fontWeight: parseFontWeight(el.fontWeight),
    fontStyle: el.fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
    color: el.textGradient != null ? Colors.transparent : hexToFlutter(el.color),
    height: el.lineHeight,
  );
  return textStyle;
}

String _safeFontFamily(String family) {
  const googleFonts = {'Inter', 'Playfair Display', 'Lora', 'DM Mono'};
  return googleFonts.contains(family) ? family : 'Inter';
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
            color: const Color(0x140A66D6), // accent 8%
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x400A66D6), width: 1),
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
            : BorderRadius.circular(e.borderRadius),
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
    if (e.src.isEmpty) {
      return SizedBox(
        width: e.width ?? 150,
        height: e.height ?? 100,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0EFed),
            border: Border.all(
                color: const Color(0xFFC4A882), width: 1.5,
                style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(e.borderRadius),
          ),
          child: const Center(
            child: Text('Image',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9890))),
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
          borderRadius: BorderRadius.circular(e.borderRadius),
          child: Image.network(e.src,
              fit: _boxFit(e.objectFit), errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFFF0EFed),
                  child: const Icon(Icons.broken_image, color: Color(0xFF9E9890)))),
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
              Container(color: const Color(0xFFF5F5F5),
                child: const Icon(Icons.qr_code, color: Colors.grey))),
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
      borderRadius: BorderRadius.circular(e.borderRadius),
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
      // ── Row mode: equal-width slices, cross-axis stretch ─────────────────────
      // Rules:
      //   • All children share available width via Expanded (default flex = 1 each).
      //   • Gap is a plain SizedBox between slots — NOT a nested Row/Column.
      //   • Cross axis (height): stretch to full row height.
      if (e.children.isEmpty) {
        content = _emptySlot();
      } else {
        final kids = <Widget>[];
        for (int i = 0; i < e.children.length; i++) {
          if (i > 0) kids.add(SizedBox(width: e.gap));
          final c = e.children[i];
          final flex = _childFlex(c) > 0 ? _childFlex(c) : 1;
          kids.add(Expanded(
            flex: flex,
            child: ElementRenderer(
                el: c, record: record, entityName: entityName, computedFields: computedFields),
          ));
        }
        content = Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kids,
        );
      }
    } else {
      // ── Column mode: full-width children, per-child heights ──────────────────
      // Rules:
      //   • Children fill full inner width (CrossAxisAlignment.stretch).
      //   • Height from child.height when set; otherwise intrinsic (text wraps, etc.).
      //   • Gap is a plain SizedBox between slots.
      if (e.children.isEmpty) {
        content = _emptySlot();
      } else {
        final kids = <Widget>[];
        for (int i = 0; i < e.children.length; i++) {
          if (i > 0) kids.add(SizedBox(height: e.gap));
          final c = e.children[i];
          kids.add(SizedBox(
            width: double.infinity,
            height: c.height, // null → shrink-wrap to child's intrinsic height
            child: ElementRenderer(
                el: c, record: record, entityName: entityName, computedFields: computedFields),
          ));
        }
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kids,
        );
      }
    }

    return SizedBox(
      width: e.width,
      height: e.height,
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
        color: const Color(0x08000000),
        child: const Center(
          child: Text('Empty',
              style: TextStyle(fontSize: 10, color: Color(0x38000000))),
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
