import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/element_model.dart';
import '../models/flow_layout.dart';
import '../models/table_element.dart';
import '../models/table_layout.dart';
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
    // No cast. A section is any element that flows down the page, and since
    // the table element gained a settable `isSection` that is no longer only a
    // ContainerElement — the old `.cast<ContainerElement>()` threw on the first
    // flowing table. `_renderElement` already dispatches by type.
    final sections = elements.where((e) => e.isSection).toList();
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

  /// [paginate] controls whether content may spill onto further pages.
  ///
  /// `null` (the default) means **auto**: paginate when the template is
  /// flow-only, i.e. every element is a section with no absolute `x`/`y`.
  /// That restriction is not a policy choice — a `pw.Positioned` inside a
  /// `pw.Stack` has no meaning once content reflows across pages, so only a
  /// plain vertical list of sections can be handed to `pw.MultiPage`.
  ///
  /// Every template authored before this existed has absolute coordinates and
  /// therefore keeps the single-page path byte for byte.
  static Future<Uint8List> buildPdf({
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
    bool? paginate,
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

    if (paginate ?? isFlowOnly(elements)) {
      doc.addPage(pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          buildBackground: (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _hex(template.backgroundColor)),
          ),
        ),
        build: (_) => [
          for (final e in elements)
            _renderElement(
                e, fonts, imageCache, record, entityName, computedFields),
        ],
      ));
      return doc.save();
    }

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
    if (e is TableElement) return _renderTable(e, fonts, record, entityName, computedFields);
    return pw.SizedBox();
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  /// Built on `pw.Table` rather than composed from the row/col path, for three
  /// reasons that all matter on a real invoice:
  ///
  /// - **Column edges line up.** A `pw.Row` of `Expanded` cells cannot keep
  ///   columns aligned once one cell wraps to two lines; `columnWidths` does it
  ///   by construction.
  /// - **The header repeats.** `pw.TableRow(repeat: true)` redraws the header
  ///   on every page a long table spills onto. Hand-composed rows lose that.
  /// - **It spans pages.** `pw.Table` is one of the pdf package's spanning
  ///   widgets; a `pw.Column` of rows is not, and would overflow rather than
  ///   paginate — which would make the MultiPage path pointless for exactly the
  ///   element that needs it most.
  static pw.Widget _renderTable(
      TableElement e,
      _FontSet fonts,
      Map<String, dynamic>? record,
      String? entityName,
      List<ComputedField> computedFields) {
    final t = resolveTable(e, record,
        entityName: entityName, computedFields: computedFields);

    if (t.columns.isEmpty || t.isEmpty) {
      return pw.Container(
        padding: pw.EdgeInsets.symmetric(
            horizontal: _pxToPt(e.cellPaddingX), vertical: _pxToPt(6)),
        child: pw.Text(
          e.emptyText,
          style: pw.TextStyle(
              font: fonts.regular,
              fontSize: _pxToPt(e.fontSize),
              color: _hex(e.headerColor)),
        ),
      );
    }

    final hairline = pw.BorderSide(
        color: _hex(e.gridColor), width: _pxToPt(e.gridWidth));

    pw.Widget cell(String text, TableColumn col,
            {required bool header}) =>
        pw.Container(
          height: _pxToPt(header ? e.headerHeight : e.rowHeight),
          alignment: _cellAlignment(col.align),
          padding:
              pw.EdgeInsets.symmetric(horizontal: _pxToPt(e.cellPaddingX)),
          child: pw.Text(
            text,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: _cellTextAlign(col.align),
            style: pw.TextStyle(
              font: header ? fonts.bold : fonts.regular,
              fontSize: _pxToPt(header ? e.headerFontSize : e.fontSize),
              color: _hex(header ? e.headerColor : e.color),
            ),
          ),
        );

    final rows = <pw.TableRow>[
      if (e.showHeader)
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(
            color: _hex(e.headerBackground),
            border: pw.Border(bottom: hairline),
          ),
          children: [
            for (final col in t.columns)
              cell(
                  record != null
                      ? TokenService.resolveTokens(
                          col.label, record, entityName, computedFields)
                      : col.label,
                  col,
                  header: true),
          ],
        ),
      for (var r = 0; r < t.cells.length; r++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: e.zebra && r.isOdd ? _hex(e.zebraColor) : null,
            border: pw.Border(bottom: hairline),
          ),
          children: [
            for (var c = 0; c < t.columns.length; c++)
              cell(t.cells[r][c], t.columns[c], header: false),
          ],
        ),
    ];

    final table = pw.Table(
      columnWidths: _pdfColumnWidths(t.columns),
      children: rows,
    );

    // A clipped table that says nothing reads as a complete one.
    if (t.overflow == null) return table;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        table,
        pw.Container(
          padding: pw.EdgeInsets.symmetric(
              horizontal: _pxToPt(e.cellPaddingX), vertical: _pxToPt(4)),
          child: pw.Text(t.overflow!,
              style: pw.TextStyle(
                  font: fonts.italic,
                  fontSize: _pxToPt(e.fontSize),
                  color: _hex(e.headerColor))),
        ),
      ],
    );
  }

  /// Fixed columns keep their width; the rest split what is left by flex.
  static Map<int, pw.TableColumnWidth> _pdfColumnWidths(
      List<TableColumn> columns) {
    final out = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < columns.length; i++) {
      final c = columns[i];
      out[i] = c.width != null
          ? pw.FixedColumnWidth(_pxToPt(c.width!))
          : pw.FlexColumnWidth(c.flex);
    }
    return out;
  }

  static pw.Alignment _cellAlignment(String align) => switch (align) {
        'right' => pw.Alignment.centerRight,
        'center' => pw.Alignment.center,
        _ => pw.Alignment.centerLeft,
      };

  static pw.TextAlign _cellTextAlign(String align) => switch (align) {
        'right' => pw.TextAlign.right,
        'center' => pw.TextAlign.center,
        _ => pw.TextAlign.left,
      };

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
      final align = containerAlign(e);
      final kids = <pw.Widget>[];
      for (int i = 0; i < e.children.length; i++) {
        if (i > 0) {
          kids.add(isRow
              ? pw.SizedBox(width: _pxToPt(e.gap))
              : pw.SizedBox(height: _pxToPt(e.gap)));
        }
        final c = e.children[i];
        final slot = slotFor(e, c);
        var child =
            _renderElement(c, fonts, imageCache, record, entityName, computedFields);

        // alignSelf used to be honoured on the editor canvas and dropped here,
        // so a designer nudged a child in the preview and the PDF ignored it.
        if (slot.align != null && slot.align != FlowAlign.stretch) {
          child = pw.Align(
            alignment: _pdfAlignment(slot.align!, isRow: isRow),
            child: child,
          );
        }

        if (slot.expand) {
          kids.add(pw.Expanded(flex: slot.flex, child: child));
        } else {
          kids.add(pw.SizedBox(
            width: slot.stretchWidth ? double.infinity : null,
            height:
                slot.fixedHeight != null ? _pxToPt(slot.fixedHeight!) : null,
            child: child,
          ));
        }
      }
      content = isRow
          ? pw.Row(
              mainAxisSize: pw.MainAxisSize.max,
              crossAxisAlignment: _pdfCrossAxis(align),
              children: kids,
            )
          : pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              crossAxisAlignment: _pdfCrossAxis(align),
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

  static pw.CrossAxisAlignment _pdfCrossAxis(FlowAlign a) => switch (a) {
        FlowAlign.start => pw.CrossAxisAlignment.start,
        FlowAlign.center => pw.CrossAxisAlignment.center,
        FlowAlign.end => pw.CrossAxisAlignment.end,
        FlowAlign.stretch => pw.CrossAxisAlignment.stretch,
      };

  /// A child's own alignment inside its slot. The cross axis of a row is
  /// vertical and of a column horizontal, so the same [FlowAlign] maps to
  /// different corners depending on the parent.
  static pw.Alignment _pdfAlignment(FlowAlign a, {required bool isRow}) {
    if (isRow) {
      return switch (a) {
        FlowAlign.start => pw.Alignment.topCenter,
        FlowAlign.center => pw.Alignment.center,
        FlowAlign.end => pw.Alignment.bottomCenter,
        FlowAlign.stretch => pw.Alignment.center,
      };
    }
    return switch (a) {
      FlowAlign.start => pw.Alignment.centerLeft,
      FlowAlign.center => pw.Alignment.center,
      FlowAlign.end => pw.Alignment.centerRight,
      FlowAlign.stretch => pw.Alignment.center,
    };
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
