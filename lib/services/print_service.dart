import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/element_model.dart';
import '../models/template_model.dart';
import '../services/token_service.dart';

double _pxToPt(double px) => px * 0.75;

PdfColor _hex(String hex) {
  try {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    final v = int.parse(h, radix: 16);
    return PdfColor.fromInt(0xFF000000 | v);
  } catch (_) {
    return PdfColors.black;
  }
}

pw.BorderRadius _pdfCorners(CornerRadii c) {
  if (c.isUniform) {
    return pw.BorderRadius.circular(_pxToPt(c.borderRadius));
  }
  return pw.BorderRadius.only(
    topLeft: pw.Radius.circular(_pxToPt(c.topLeft)),
    topRight: pw.Radius.circular(_pxToPt(c.topRight)),
    bottomRight: pw.Radius.circular(_pxToPt(c.bottomRight)),
    bottomLeft: pw.Radius.circular(_pxToPt(c.bottomLeft)),
  );
}

class PrintService {
  // ── Fonts ──────────────────────────────────────────────────────────────────

  static Future<_FontSet> _loadFonts() async {
    try {
      return _FontSet(
        regular: await PdfGoogleFonts.interRegular(),
        bold: await PdfGoogleFonts.interBold(),
        italic: await PdfGoogleFonts.interItalic(),
        mono: pw.Font.courier(),
      );
    } catch (_) {
      return _FontSet(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        mono: pw.Font.courier(),
      );
    }
  }

  // ── Page builder (shared by single, batch, and N-up) ──────────────────────

  static pw.Widget _buildPageContent(
    List<CanvasElement> elements,
    _FontSet fonts,
    Map<String, pw.MemoryImage> imageCache,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields,
    String bgColor,
  ) {
    final sections = elements.where((e) => e.isSection).cast<ContainerElement>();
    final sorted = elements
        .where((e) => !e.isSection && e.x != null && e.y != null)
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return pw.ConstrainedBox(
      constraints: const pw.BoxConstraints.expand(),
      child: pw.Stack(children: [
        pw.Container(color: _hex(bgColor)),
        if (sections.isNotEmpty)
          pw.Positioned(
            top: 0, left: 0, right: 0,
            child: pw.Column(
              children: sections
                  .map((e) => _renderElement(
                      e, fonts, imageCache, record, entityName, computedFields))
                  .toList(),
            ),
          ),
        ...sorted.map((e) {
          final child = _renderElement(
              e, fonts, imageCache, record, entityName, computedFields);
          return pw.Positioned(
            left: _pxToPt(e.x!),
            top: _pxToPt(e.y!),
            child: e.rotation != 0
                ? pw.Transform.rotate(
                    angle: e.rotation * 3.14159265 / 180, child: child)
                : child,
          );
        }),
      ]),
    );
  }

  // ── Single record PDF ──────────────────────────────────────────────────────

  static Future<Uint8List> buildPdf({
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();
    final imageCache = <String, pw.MemoryImage>{};
    await _prefetchImages(elements, imageCache, record, entityName, computedFields);

    final pageFormat = PdfPageFormat(
      template.canvasWidthMm * PdfPageFormat.mm,
      template.canvasHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (_) => _buildPageContent(elements, fonts, imageCache,
          record, entityName, computedFields, template.backgroundColor),
    ));

    return doc.save();
  }

  // ── Batch PDF — one page per record ───────────────────────────────────────

  /// Produces a multi-page PDF with one page per record in [records].
  ///
  /// ```dart
  /// final bytes = await PrintService.buildPdfBatch(
  ///   template: template,
  ///   elements: elements,
  ///   records: workOrders.map((wo) => {
  ///     'work_order.number': wo.number,
  ///     'customer.name':     wo.customerName,
  ///   }).toList(),
  ///   entityName: 'work_order',
  /// );
  /// ```
  static Future<Uint8List> buildPdfBatch({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();
    final pageFormat = PdfPageFormat(
      template.canvasWidthMm * PdfPageFormat.mm,
      template.canvasHeightMm * PdfPageFormat.mm,
      marginAll: 0,
    );

    for (final record in records) {
      final imageCache = <String, pw.MemoryImage>{};
      await _prefetchImages(elements, imageCache, record, entityName, computedFields);
      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        build: (_) => _buildPageContent(elements, fonts, imageCache,
            record, entityName, computedFields, template.backgroundColor),
      ));
    }

    return doc.save();
  }

  /// Batch-print directly to the OS print dialog (one page per record).
  static Future<void> printDirectBatch({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) async {
    await Printing.layoutPdf(
      name: template.name,
      onLayout: (_) => buildPdfBatch(
        template: template,
        elements: elements,
        records: records,
        entityName: entityName,
        computedFields: computedFields,
      ),
    );
  }

  // ── N-up sheet PDF — tile labels onto a larger sheet ──────────────────────

  /// Tiles [records] as individual labels onto a sheet (e.g. A4), fitting as
  /// many columns × rows as the sheet allows with [marginMm] outer margin and
  /// [gapMm] spacing between labels.
  ///
  /// ```dart
  /// final bytes = await PrintService.buildSheetPdf(
  ///   template: template,   // label size defined here
  ///   elements: elements,
  ///   records: allWorkOrders,
  ///   sheetWidthMm:  210,   // A4 portrait
  ///   sheetHeightMm: 297,
  ///   marginMm: 10,
  ///   gapMm: 3,
  /// );
  /// ```
  static Future<Uint8List> buildSheetPdf({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    double sheetWidthMm = 210,   // A4 portrait
    double sheetHeightMm = 297,
    double marginMm = 8,
    double gapMm = 3,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();

    final labelW = template.canvasWidthMm * PdfPageFormat.mm;
    final labelH = template.canvasHeightMm * PdfPageFormat.mm;
    final marginPt = marginMm * PdfPageFormat.mm;
    final gapPt = gapMm * PdfPageFormat.mm;
    final sheetW = sheetWidthMm * PdfPageFormat.mm;
    final sheetH = sheetHeightMm * PdfPageFormat.mm;

    final usableW = sheetW - marginPt * 2;
    final usableH = sheetH - marginPt * 2;
    final cols = ((usableW + gapPt) / (labelW + gapPt)).floor().clamp(1, 9999);
    final rows = ((usableH + gapPt) / (labelH + gapPt)).floor().clamp(1, 9999);
    final perPage = cols * rows;

    final sheetFormat = PdfPageFormat(sheetW, sheetH, marginAll: 0);

    // Split records into pages
    for (int pageStart = 0; pageStart < records.length; pageStart += perPage) {
      final pageRecords = records.skip(pageStart).take(perPage).toList();

      // Pre-fetch images for all records on this sheet page (deduplicated)
      final imageCache = <String, pw.MemoryImage>{};
      for (final rec in pageRecords) {
        await _prefetchImages(elements, imageCache, rec, entityName, computedFields);
      }

      doc.addPage(pw.Page(
        pageFormat: sheetFormat,
        build: (_) {
          final labels = <pw.Widget>[];
          for (int i = 0; i < pageRecords.length; i++) {
            final col = i % cols;
            final row = i ~/ cols;
            final x = marginPt + col * (labelW + gapPt);
            final y = marginPt + row * (labelH + gapPt);
            labels.add(pw.Positioned(
              left: x,
              top: y,
              child: pw.SizedBox(
                width: labelW,
                height: labelH,
                child: _buildPageContent(
                  elements, fonts, imageCache,
                  pageRecords[i], entityName, computedFields,
                  template.backgroundColor,
                ),
              ),
            ));
          }
          return pw.Stack(children: labels);
        },
      ));
    }

    return doc.save();
  }

  /// Print an N-up label sheet directly to the OS print dialog.
  static Future<void> printSheetDirect({
    required Template template,
    required List<CanvasElement> elements,
    required List<Map<String, dynamic>> records,
    double sheetWidthMm = 210,
    double sheetHeightMm = 297,
    double marginMm = 8,
    double gapMm = 3,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) async {
    await Printing.layoutPdf(
      name: '${template.name} — sheet',
      onLayout: (_) => buildSheetPdf(
        template: template,
        elements: elements,
        records: records,
        sheetWidthMm: sheetWidthMm,
        sheetHeightMm: sheetHeightMm,
        marginMm: marginMm,
        gapMm: gapMm,
        entityName: entityName,
        computedFields: computedFields,
      ),
    );
  }

  static pw.Widget _renderElement(
      CanvasElement e,
      _FontSet fonts,
      Map<String, pw.MemoryImage> imageCache,
      Map<String, dynamic>? record,
      String? entityName,
      List<ComputedField> computedFields) {
    if (e is TextElement) return _renderText(e, fonts, record, entityName, computedFields);
    if (e is ShapeElement) return _renderShape(e);
    if (e is ImageElement) return _renderImage(e, imageCache);
    if (e is QrElement) return _renderQr(e, imageCache, record, entityName, computedFields);
    if (e is BarcodeElement) return _renderBarcode(e, record, entityName, computedFields);
    if (e is ContainerElement) return _renderContainer(e, fonts, imageCache, record, entityName, computedFields);
    return pw.SizedBox();
  }

  static pw.Widget _renderText(
      TextElement e,
      _FontSet fonts,
      Map<String, dynamic>? record,
      String? entityName,
      List<ComputedField> computedFields) {
    final content = record != null
        ? TokenService.resolveTokens(e.content, record, entityName, computedFields)
        : e.content;

    final isMono = e.fontFamily == 'DM Mono' ||
        e.fontFamily.toLowerCase().contains('courier') ||
        e.fontFamily.toLowerCase().contains('mono');
    final isBold = e.fontWeight == 'bold' || e.fontWeight == '700' || e.fontWeight == '800' || e.fontWeight == '600';
    final isItalic = e.fontStyle == 'italic';

    pw.Font font;
    if (isMono) {
      font = fonts.mono;
    } else if (isBold) {
      font = fonts.bold;
    } else if (isItalic) {
      font = fonts.italic;
    } else {
      font = fonts.regular;
    }

    final textAlign = switch (e.textAlign) {
      'center' => pw.TextAlign.center,
      'right' => pw.TextAlign.right,
      'justify' => pw.TextAlign.justify,
      _ => pw.TextAlign.left,
    };

    PdfColor color = _hex(e.color);
    if (e.textGradient != null && e.textGradient!.stops.isNotEmpty) {
      color = _hex(e.textGradient!.stops.first.color);
    }

    final style = pw.TextStyle(
      font: font,
      fontSize: _pxToPt(e.fontSize),
      color: color,
      lineSpacing: (e.lineHeight - 1) * _pxToPt(e.fontSize) * 0.5,
    );

    return pw.Opacity(
      opacity: e.opacity,
      child: pw.SizedBox(
        width: e.width != null ? _pxToPt(e.width!) : null,
        height: e.height != null ? _pxToPt(e.height!) : null,
        child: pw.Text(content, style: style, textAlign: textAlign),
      ),
    );
  }

  static pw.Widget _renderShape(ShapeElement e) {
    final isCircle = e.shape == 'circle';
    final isLine = e.shape == 'line';
    final w = _pxToPt(e.width ?? 120);
    final h = _pxToPt(e.height ?? (isLine ? 2 : 80));

    PdfColor? fillColor;
    if (e.fill != 'transparent') fillColor = _hex(e.fill);

    pw.BoxDecoration decoration;
    if (isLine) {
      decoration = pw.BoxDecoration(color: fillColor ?? _hex(e.stroke));
    } else {
      decoration = pw.BoxDecoration(
        color: e.gradient == null ? fillColor : null,
        gradient: e.gradient != null ? _pdfGradient(e.gradient!) : null,
        border: pw.Border.all(color: _hex(e.stroke), width: _pxToPt(e.strokeWidth)),
        borderRadius: isCircle
            ? pw.BorderRadius.circular(10000)
            : _pdfCorners(e.corners),
      );
    }

    return pw.Opacity(
      opacity: e.opacity,
      child: pw.Container(width: w, height: h, decoration: decoration),
    );
  }

  static pw.Widget _renderImage(ImageElement e, Map<String, pw.MemoryImage> imageCache) {
    final w = _pxToPt(e.width ?? 150);
    final h = _pxToPt(e.height ?? 100);
    if (e.src.isNotEmpty && imageCache.containsKey(e.src)) {
      // ClipRRect is uniform-only; approximate with average when per-corner.
      final avgR = (e.corners.topLeft +
              e.corners.topRight +
              e.corners.bottomRight +
              e.corners.bottomLeft) /
          4;
      return pw.Opacity(
        opacity: e.opacity,
        child: pw.ClipRRect(
          horizontalRadius: _pxToPt(avgR),
          verticalRadius: _pxToPt(avgR),
          child: pw.Image(imageCache[e.src]!, width: w, height: h,
              fit: _pdfFit(e.objectFit)),
        ),
      );
    }
    return pw.Container(
      width: w,
      height: h,
      color: PdfColors.grey200,
      child: pw.Center(
          child: pw.Text('Image', style: pw.TextStyle(color: PdfColors.grey))),
    );
  }

  static pw.Widget _renderQr(
      QrElement e,
      Map<String, pw.MemoryImage> imageCache,
      Map<String, dynamic>? record,
      String? entityName,
      List<ComputedField> computedFields) {
    final content = record != null
        ? TokenService.resolveTokens(e.content, record, entityName, computedFields)
        : e.content;
    final size = [e.width ?? 80, e.height ?? 80].reduce((a, b) => a < b ? a : b).round();
    final url =
        'https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(content)}&size=${size}x$size&margin=0';
    final w = _pxToPt(e.width ?? 80);
    final h = _pxToPt(e.height ?? 80);
    if (imageCache.containsKey(url)) {
      return pw.Opacity(
          opacity: e.opacity,
          child: pw.Image(imageCache[url]!, width: w, height: h));
    }
    return pw.Container(width: w, height: h, color: PdfColors.grey200);
  }

  static pw.Widget _renderBarcode(
      BarcodeElement e,
      Map<String, dynamic>? record,
      String? entityName,
      List<ComputedField> computedFields) {
    final content = record != null
        ? TokenService.resolveTokens(e.content, record, entityName, computedFields)
        : e.content;
    final w = _pxToPt(e.width ?? 200);
    final h = _pxToPt(e.height ?? 80);
    return pw.Opacity(
      opacity: e.opacity,
      child: pw.BarcodeWidget(
        barcode: _detectBarcode(content),
        data: content,
        width: w,
        height: h,
        color: _hex(e.color),
        backgroundColor: _hex(e.background),
        drawText: e.displayValue,
        textPadding: 2,
      ),
    );
  }

  /// Auto-detect the right barcode symbology from the content value:
  /// - 13 pure digits → EAN-13
  /// - 8 pure digits  → EAN-8
  /// - 12 pure digits → UPC-A
  /// - URL or >25 chars → QR code
  /// - everything else → Code 128
  static pw.Barcode _detectBarcode(String content) {
    final onlyDigits = RegExp(r'^\d+$').hasMatch(content);
    if (onlyDigits) {
      if (content.length == 13) return pw.Barcode.ean13();
      if (content.length == 8)  return pw.Barcode.ean8();
      if (content.length == 12) return pw.Barcode.upcA();
    }
    if (content.startsWith('http') || content.length > 25) {
      return pw.Barcode.qrCode();
    }
    return pw.Barcode.code128();
  }

  static pw.Widget _renderContainer(
      ContainerElement e,
      _FontSet fonts,
      Map<String, pw.MemoryImage> imageCache,
      Map<String, dynamic>? record,
      String? entityName,
      List<ComputedField> computedFields) {
    PdfColor? bgColor;
    if (e.background != 'transparent') bgColor = _hex(e.background);

    pw.Widget content;
    if (e.freePlacement) {
      content = pw.Stack(
        children: e.children.map((c) {
          final child = _renderElement(c, fonts, imageCache, record, entityName, computedFields);
          if (c.x != null && c.y != null) {
            return pw.Positioned(left: _pxToPt(c.x!), top: _pxToPt(c.y!), child: child);
          }
          return child;
        }).toList(),
      );
    } else {
      final isRow = e.type == 'row';
      final kids = <pw.Widget>[];
      for (int i = 0; i < e.children.length; i++) {
        if (i > 0) {
          kids.add(isRow
              ? pw.SizedBox(width: _pxToPt(e.gap))
              : pw.SizedBox(height: _pxToPt(e.gap)));
        }
        final c = e.children[i];
        final child = _renderElement(c, fonts, imageCache, record, entityName, computedFields);
        if (isRow) {
          // Equal-width slices: Expanded with flex ≥ 1
          final flex = _childFlex(c) > 0 ? _childFlex(c) : 1;
          kids.add(pw.Expanded(flex: flex, child: child));
        } else {
          // Column: full-width children, use stored height or intrinsic
          kids.add(pw.SizedBox(
            width: double.infinity,
            height: c.height != null ? _pxToPt(c.height!) : null,
            child: child,
          ));
        }
      }
      content = isRow
          ? pw.Row(
              mainAxisSize: pw.MainAxisSize.max,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: kids,
            )
          : pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: kids,
            );
    }

    return pw.Opacity(
      opacity: e.opacity,
      child: pw.Container(
        width: e.isSection
            ? double.infinity
            : (e.width != null ? _pxToPt(e.width!) : null),
        height: e.isSection
            ? null
            : (e.height != null ? _pxToPt(e.height!) : null),
        constraints: e.isSection
            ? pw.BoxConstraints(minHeight: _pxToPt(e.minHeight))
            : null,
        decoration: pw.BoxDecoration(
          color: e.gradient == null ? bgColor : null,
          gradient: e.gradient != null ? _pdfGradient(e.gradient!) : null,
          borderRadius: _pdfCorners(e.corners),
        ),
        padding: pw.EdgeInsets.all(_pxToPt(e.padding)),
        child: content,
      ),
    );
  }

  static int _childFlex(CanvasElement c) {
    if (c is TextElement) return c.flex ?? 0;
    if (c is ShapeElement) return c.flex ?? 0;
    if (c is ImageElement) return c.flex ?? 0;
    if (c is ContainerElement) return c.flex ?? 0;
    return 0;
  }

  static pw.LinearGradient _pdfGradient(dynamic gd) {
    // gd is GradientDef — access via dynamic to avoid import cycle
    try {
      final stops = (gd.stops as List)
          .map((s) => _hex(s.color as String))
          .toList();
      final positions = (gd.stops as List).map((s) => (s.pos as double) / 100).toList();
      return pw.LinearGradient(colors: stops, stops: positions);
    } catch (_) {
      return pw.LinearGradient(colors: [PdfColors.white, PdfColors.grey]);
    }
  }

  static pw.BoxFit _pdfFit(String fit) => switch (fit) {
        'contain' => pw.BoxFit.contain,
        'fill' => pw.BoxFit.fill,
        'none' => pw.BoxFit.none,
        _ => pw.BoxFit.cover,
      };

  static Future<void> _prefetchImages(
    List<CanvasElement> elements,
    Map<String, pw.MemoryImage> cache,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields,
  ) async {
    for (final e in elements) {
      if (e is ImageElement && e.src.isNotEmpty && !cache.containsKey(e.src)) {
        final bytes = await _fetch(e.src);
        if (bytes != null) cache[e.src] = pw.MemoryImage(bytes);
      } else if (e is QrElement) {
        final content = record != null
            ? TokenService.resolveTokens(e.content, record, entityName, computedFields)
            : e.content;
        final size = [e.width ?? 80, e.height ?? 80].reduce((a, b) => a < b ? a : b).round();
        final url =
            'https://api.qrserver.com/v1/create-qr-code/?data=${Uri.encodeComponent(content)}&size=${size}x$size&margin=0';
        if (!cache.containsKey(url)) {
          final bytes = await _fetch(url);
          if (bytes != null) cache[url] = pw.MemoryImage(bytes);
        }
      } else if (e is ContainerElement) {
        await _prefetchImages(e.children, cache, record, entityName, computedFields);
      }
    }
  }

  static Future<Uint8List?> _fetch(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  static Future<void> printDirect({
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
  }) async {
    await Printing.layoutPdf(
      name: template.name,
      onLayout: (_) => buildPdf(
        template: template,
        elements: elements,
        record: record,
        entityName: entityName,
        computedFields: computedFields,
      ),
    );
  }
}

class _FontSet {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  final pw.Font mono;
  const _FontSet({required this.regular, required this.bold, required this.italic, required this.mono});
}
