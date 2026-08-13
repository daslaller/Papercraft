class CanvasSize {
  final String key;
  final String label;
  final double widthMm;
  final double heightMm;
  final String category; // 'label' | 'document' | 'both'

  const CanvasSize({
    required this.key,
    required this.label,
    required this.widthMm,
    required this.heightMm,
    required this.category,
  });
}

const kCanvasSizes = [
  CanvasSize(key: 'A4', label: 'A4', widthMm: 210, heightMm: 297, category: 'document'),
  CanvasSize(key: 'Letter', label: 'Letter', widthMm: 215.9, heightMm: 279.4, category: 'document'),
  CanvasSize(key: 'A5', label: 'A5', widthMm: 148, heightMm: 210, category: 'document'),
  CanvasSize(key: '4x6', label: '4×6 Label', widthMm: 101.6, heightMm: 152.4, category: 'label'),
  CanvasSize(key: '2x2', label: '2×2 Sticker', widthMm: 50.8, heightMm: 50.8, category: 'label'),
  CanvasSize(key: '3x1', label: '3×1 Strip', widthMm: 76.2, heightMm: 25.4, category: 'label'),
  CanvasSize(key: '4x4', label: '4×4 Square', widthMm: 101.6, heightMm: 101.6, category: 'label'),
  CanvasSize(key: 'custom', label: 'Custom', widthMm: 100, heightMm: 100, category: 'both'),
];

double mmToPx(double mm) => mm * 3.7795275591;
double pxToMm(double px) => px / 3.7795275591;

class Template {
  final String id;
  final String name;
  final String docType; // 'label' | 'document'
  final String canvasSize;
  final double canvasWidthMm;
  final double canvasHeightMm;
  final String backgroundColor;
  final String elements; // JSON string
  final String? connectedEntity;
  final String? thumbnailUrl;
  /// Human-readable printer name (display + fallback match).
  final String? printerName;
  /// Stable printer id from [PapercraftPrinter.id] when associated.
  final String? printerId;
  /// Optional LOCAL fallback printer, used when the primary associated printer
  /// (e.g. a cloud/PrintNode printer) can't be resolved at print time — so a
  /// template still prints on the desk printer when the network printer is off.
  final String? fallbackPrinterName;
  final String? fallbackPrinterId;
  /// When true, new row/col containers are flow sections at the top of the page.
  /// When false, row/col are freely positioned on the canvas.
  final bool sectionLayoutEnabled;

  /// What this template IS, for a host that ships more than one design.
  ///
  /// [docType] is the canvas category — `label` or `document` — which is what
  /// the dashboard filters and the size presets key off, and it is deliberately
  /// coarse. A host with an invoice, an estimate, an intake slip and two
  /// insurance forms cannot tell them apart by it: all five are `document`, so
  /// "the default document" collapses five designs into one slot.
  ///
  /// [docRole] is the host's own identifier for the slot ('invoice',
  /// 'ticket_label'). Nullable, so every template written before this existed
  /// is unaffected, and untouched by Papercraft itself beyond storage — the
  /// host decides what the values mean.
  final String? docRole;
  /// Explicit per-doc-type default. The host app's storage sets this for the
  /// one template per [docType] that should be picked when printing.
  /// False for all templates means fall back to "most recently updated".
  final bool isDefault;
  final String ownerId;
  final DateTime createdDate;
  final DateTime updatedDate;

  const Template({
    required this.id,
    required this.name,
    required this.docType,
    this.canvasSize = 'A4',
    this.canvasWidthMm = 210,
    this.canvasHeightMm = 297,
    this.backgroundColor = '#ffffff',
    this.elements = '[]',
    this.connectedEntity,
    this.thumbnailUrl,
    this.printerName,
    this.printerId,
    this.fallbackPrinterName,
    this.fallbackPrinterId,
    this.sectionLayoutEnabled = false,
    this.docRole,
    this.isDefault = false,
    required this.ownerId,
    required this.createdDate,
    required this.updatedDate,
  });

  Template copyWith({
    String? name,
    String? docType,
    String? canvasSize,
    double? canvasWidthMm,
    double? canvasHeightMm,
    String? backgroundColor,
    String? elements,
    String? connectedEntity,
    bool clearEntity = false,
    String? thumbnailUrl,
    String? printerName,
    String? printerId,
    bool clearPrinter = false,
    String? fallbackPrinterName,
    String? fallbackPrinterId,
    bool clearFallbackPrinter = false,
    bool? sectionLayoutEnabled,
    String? docRole,
    bool? isDefault,
    DateTime? updatedDate,
  }) =>
      Template(
        id: id,
        name: name ?? this.name,
        docType: docType ?? this.docType,
        canvasSize: canvasSize ?? this.canvasSize,
        canvasWidthMm: canvasWidthMm ?? this.canvasWidthMm,
        canvasHeightMm: canvasHeightMm ?? this.canvasHeightMm,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        elements: elements ?? this.elements,
        connectedEntity:
            clearEntity ? null : (connectedEntity ?? this.connectedEntity),
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        printerName: clearPrinter ? null : (printerName ?? this.printerName),
        printerId: clearPrinter ? null : (printerId ?? this.printerId),
        fallbackPrinterName: clearFallbackPrinter
            ? null
            : (fallbackPrinterName ?? this.fallbackPrinterName),
        fallbackPrinterId: clearFallbackPrinter
            ? null
            : (fallbackPrinterId ?? this.fallbackPrinterId),
        sectionLayoutEnabled:
            sectionLayoutEnabled ?? this.sectionLayoutEnabled,
        docRole: docRole ?? this.docRole,
        isDefault: isDefault ?? this.isDefault,
        ownerId: ownerId,
        createdDate: createdDate,
        updatedDate: updatedDate ?? this.updatedDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'docType': docType,
        'canvasSize': canvasSize,
        'canvasWidthMm': canvasWidthMm,
        'canvasHeightMm': canvasHeightMm,
        'backgroundColor': backgroundColor,
        'elements': elements,
        if (connectedEntity != null) 'connectedEntity': connectedEntity,
        if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
        if (printerName != null) 'printerName': printerName,
        if (printerId != null) 'printerId': printerId,
        if (fallbackPrinterName != null)
          'fallbackPrinterName': fallbackPrinterName,
        if (fallbackPrinterId != null) 'fallbackPrinterId': fallbackPrinterId,
        'sectionLayoutEnabled': sectionLayoutEnabled,
        if (docRole != null) 'docRole': docRole,
        'isDefault': isDefault,
        'ownerId': ownerId,
        'createdDate': createdDate.toIso8601String(),
        'updatedDate': updatedDate.toIso8601String(),
      };

  factory Template.fromJson(Map<String, dynamic> j) => Template(
        id: j['id'] as String,
        name: j['name'] as String,
        docType: j['docType'] as String? ?? 'document',
        canvasSize: j['canvasSize'] as String? ?? 'A4',
        canvasWidthMm: (j['canvasWidthMm'] as num? ?? 210).toDouble(),
        canvasHeightMm: (j['canvasHeightMm'] as num? ?? 297).toDouble(),
        backgroundColor: j['backgroundColor'] as String? ?? '#ffffff',
        elements: j['elements'] as String? ?? '[]',
        connectedEntity: j['connectedEntity'] as String?,
        thumbnailUrl: j['thumbnailUrl'] as String?,
        printerName: j['printerName'] as String?,
        printerId: j['printerId'] as String?,
        fallbackPrinterName: j['fallbackPrinterName'] as String?,
        fallbackPrinterId: j['fallbackPrinterId'] as String?,
        sectionLayoutEnabled: j['sectionLayoutEnabled'] as bool? ?? false,
        docRole: j['docRole'] as String?,
        isDefault: j['isDefault'] as bool? ?? false,
        ownerId: j['ownerId'] as String? ?? '',
        createdDate: DateTime.parse(j['createdDate'] as String),
        updatedDate: DateTime.parse(j['updatedDate'] as String),
      );
}
