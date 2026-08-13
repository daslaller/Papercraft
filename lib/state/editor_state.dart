import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Offset, Size;
import '../models/element_model.dart';
import '../models/layout_helpers.dart';
import '../models/template_model.dart';
import '../services/papercraft_storage.dart';

const _maxHistory = 30;
const kZoomSteps = [10, 25, 33, 50, 67, 75, 100, 125, 150, 200];

class SnapGuide {
  final String type; // 'h' | 'v'
  final double pos;
  const SnapGuide({required this.type, required this.pos});
}

class EditorState extends ChangeNotifier {
  EditorState({PapercraftStorage? storage})
      : _storage = storage ?? StorageRegistry.active;

  PapercraftStorage _storage;

  /// Optional callback fired after every successful persist.
  void Function(Template template)? onSaved;

  Template? _template;
  List<CanvasElement> _elements = [];
  String? _selectedId;
  String? _selectedChildId;

  // History
  final List<String> _history = [];
  int _historyIdx = -1;
  bool _suppressHistory = false;

  // View
  double _zoom = 100;
  Offset _panOffset = Offset.zero;
  Size? _viewportSize;
  Offset? _viewportGlobalOrigin;
  bool _panMode = true;
  bool _elementDragActive = false; // set by CanvasElementWidget BEFORE workspace checks
  bool _gridEnabled = false;
  bool _snapEnabled = true;
  double _gridPitch = 10;
  List<SnapGuide> _snapGuides = [];

  // Preview
  bool _previewMode = false;
  Map<String, dynamic>? _previewRecord;
  String? _previewEntityName;

  // Saving
  bool _saving = false;
  Timer? _autoSaveTimer;

  /// Minimum fraction of the canvas that must remain visible when panning.
  static const double _minVisibleFraction = 0.15;
  static const double _edgeAutoPanZone = 48;
  static const double _edgeAutoPanStep = 12;

  PapercraftStorage get storage => _storage;

  Template? get template => _template;
  List<CanvasElement> get elements => _elements;
  String? get selectedId => _selectedId;
  String? get selectedChildId => _selectedChildId;
  double get zoom => _zoom;
  Offset get panOffset => _panOffset;
  Size? get viewportSize => _viewportSize;
  bool get panMode => _panMode;
  bool get elementDragActive => _elementDragActive;
  bool get gridEnabled => _gridEnabled;
  bool get snapEnabled => _snapEnabled;
  double get gridPitch => _gridPitch;
  List<SnapGuide> get snapGuides => _snapGuides;
  bool get saving => _saving;
  bool get previewMode => _previewMode;
  Map<String, dynamic>? get previewRecord => _previewRecord;
  String? get previewEntityName => _previewEntityName;
  bool get canUndo => _historyIdx > 0;
  bool get canRedo => _historyIdx < _history.length - 1;
  bool get sectionLayoutEnabled => _template?.sectionLayoutEnabled ?? false;

  CanvasElement? get selectedElement {
    if (_selectedChildId != null) {
      return findNodeInTree(_elements, _selectedChildId!);
    }
    if (_selectedId != null) {
      return _elements.where((e) => e.id == _selectedId).firstOrNull;
    }
    return null;
  }

  bool get isChildSelected {
    final el = selectedElement;
    return el != null && el.x == null && el.y == null;
  }

  bool get isContainerSelected {
    final el = selectedElement;
    return el != null && (el.type == 'row' || el.type == 'col');
  }

  /// Swap the storage backend (e.g. when [PapercraftEditor.storage] is set).
  void setStorage(PapercraftStorage storage) {
    _storage = storage;
  }

  Future<void> load(String templateId) async {
    final t = await _storage.getById(templateId);
    if (t == null) return;
    loadFromTemplate(t);
  }

  /// Load directly from a [Template] object.
  void loadFromTemplate(Template t) {
    _template = t;
    _elements = elementsFromJson(t.elements);
    _pushHistory();
    _computeInitialZoom();
    notifyListeners();
  }

  void _computeInitialZoom() {
    if (_template == null) return;
    // Will be called after layout; set to 100 for now
    _zoom = 100;
  }

  void setZoom(double z) {
    _zoom = z.clamp(10, 400);
    _panOffset = clampPanOffset(_panOffset);
    notifyListeners();
  }

  void zoomIn() {
    final next = kZoomSteps.where((s) => s > _zoom).firstOrNull;
    _zoom = (next ?? 400).toDouble();
    _panOffset = clampPanOffset(_panOffset);
    notifyListeners();
  }

  void zoomOut() {
    final prev =
        kZoomSteps.reversed.where((s) => s < _zoom).firstOrNull;
    _zoom = (prev ?? 10).toDouble();
    _panOffset = clampPanOffset(_panOffset);
    notifyListeners();
  }

  void fitToView(double viewW, double viewH) {
    if (_template == null) return;
    final cw = mmToPx(_template!.canvasWidthMm);
    final ch = mmToPx(_template!.canvasHeightMm);
    final fw = (viewW - 96) / cw * 100;
    final fh = (viewH - 96) / ch * 100;
    _zoom = [fw, fh, 200.0].reduce((a, b) => a < b ? a : b).clamp(10, 200);
    final scale = _zoom / 100;
    // Canvas renders at (48 + panOffset.dx, 48 + panOffset.dy) because OverflowBox
    // places Center at (0,0) with infinite constraints (Center shrinks to child size).
    // So to center the canvas: 48 + panX = (viewW - cw*scale) / 2
    _viewportSize ??= Size(viewW, viewH);
    _panOffset = clampPanOffset(Offset(
      (viewW - cw * scale) / 2 - 48,
      (viewH - ch * scale) / 2 - 48,
    ));
    notifyListeners();
  }

  void startElementDrag() => _elementDragActive = true;
  void endElementDrag() => _elementDragActive = false;

  void setViewportGeometry(Size size, Offset globalOrigin) {
    final sizeChanged = _viewportSize != size;
    final originChanged = _viewportGlobalOrigin != globalOrigin;
    if (!sizeChanged && !originChanged) return;
    _viewportSize = size;
    _viewportGlobalOrigin = globalOrigin;
    _panOffset = clampPanOffset(_panOffset);
    notifyListeners();
  }

  void setPanOffset(Offset o) {
    _panOffset = clampPanOffset(o);
    notifyListeners();
  }

  /// Clamp [offset] so a minimum portion of the canvas stays in the viewport.
  Offset clampPanOffset(Offset offset) {
    final view = _viewportSize;
    final t = _template;
    if (view == null || t == null) return offset;

    final scale = _zoom / 100;
    final cw = mmToPx(t.canvasWidthMm) * scale;
    final ch = mmToPx(t.canvasHeightMm) * scale;
    final minVisibleW = cw * _minVisibleFraction;
    final minVisibleH = ch * _minVisibleFraction;

    // Canvas is drawn at (48 + pan.dx, 48 + pan.dy) in workspace coords.
    const pad = 48.0;
    final minX = minVisibleW - cw - pad;
    final maxX = view.width - minVisibleW - pad;
    final minY = minVisibleH - ch - pad;
    final maxY = view.height - minVisibleH - pad;

    return Offset(
      offset.dx.clamp(minX < maxX ? minX : maxX, minX < maxX ? maxX : minX),
      offset.dy.clamp(minY < maxY ? minY : maxY, minY < maxY ? maxY : minY),
    );
  }

  /// Auto-pan the viewport when an element drag pointer is near an edge.
  /// [localPosition] is in workspace/viewport coordinates.
  void autoPanForPointer(Offset localPosition) {
    final view = _viewportSize;
    if (view == null) return;

    var dx = 0.0;
    var dy = 0.0;
    if (localPosition.dx < _edgeAutoPanZone) {
      dx = _edgeAutoPanStep;
    } else if (localPosition.dx > view.width - _edgeAutoPanZone) {
      dx = -_edgeAutoPanStep;
    }
    if (localPosition.dy < _edgeAutoPanZone) {
      dy = _edgeAutoPanStep;
    } else if (localPosition.dy > view.height - _edgeAutoPanZone) {
      dy = -_edgeAutoPanStep;
    }
    if (dx == 0 && dy == 0) return;
    setPanOffset(_panOffset + Offset(dx, dy));
  }

  /// Same as [autoPanForPointer] but accepts a global screen position.
  void autoPanForGlobalPointer(Offset globalPosition) {
    final origin = _viewportGlobalOrigin;
    if (origin == null) return;
    autoPanForPointer(globalPosition - origin);
  }

  void setPanMode(bool v) {
    _panMode = v;
    notifyListeners();
  }

  void toggleGrid() {
    _gridEnabled = !_gridEnabled;
    notifyListeners();
  }

  void toggleSnap() {
    _snapEnabled = !_snapEnabled;
    notifyListeners();
  }

  void setGridPitch(double pitch) {
    _gridPitch = pitch.clamp(2, 100);
    notifyListeners();
  }

  void setSnapGuides(List<SnapGuide> guides) {
    _snapGuides = guides;
    notifyListeners();
  }

  void setPreviewMode(bool v) {
    _previewMode = v;
    notifyListeners();
  }

  void setPreviewRecord(Map<String, dynamic>? record, String? entityName) {
    _previewRecord = record;
    _previewEntityName = entityName;
    notifyListeners();
  }

  void setSectionLayoutEnabled(bool enabled) {
    if (_template == null || _template!.sectionLayoutEnabled == enabled) return;
    _template = _template!.copyWith(sectionLayoutEnabled: enabled);
    _scheduleAutoSave();
    notifyListeners();
  }

  void toggleSectionLayout() =>
      setSectionLayoutEnabled(!sectionLayoutEnabled);

  void select(String? id) {
    _selectedId = id;
    _selectedChildId = null;
    notifyListeners();
  }

  void selectChild(String? childId) {
    _selectedChildId = childId;
    notifyListeners();
  }

  void deselect() {
    _selectedId = null;
    _selectedChildId = null;
    notifyListeners();
  }

  // ── Elements ────────────────────────────────────────────────────────────────

  void addElement(CanvasElement el) {
    final maxZ = _elements.isEmpty
        ? 0
        : _elements
            .map((e) => e.zIndex)
            .reduce((a, b) => a > b ? a : b);
    CanvasElement toAdd = el;
    if (!el.isSection) {
      // Bump zIndex
      toAdd = _withZIndex(el, maxZ + 1);
    }
    _elements = [..._elements, toAdd];
    _selectedId = el.id;
    _selectedChildId = null;
    _pushHistory();
    _scheduleAutoSave();
    notifyListeners();
  }

  void addLayoutContainer(String type) {
    final el = sectionLayoutEnabled
        ? ContainerElement.createSection(type)
        : ContainerElement.createAbsolute(type);
    addElement(el);
  }

  CanvasElement _withZIndex(CanvasElement el, int z) {
    if (el is TextElement) return el.copyWith(zIndex: z);
    if (el is ShapeElement) return el.copyWith(zIndex: z);
    if (el is ImageElement) return el.copyWith(zIndex: z);
    if (el is QrElement) return el.copyWith(zIndex: z);
    if (el is BarcodeElement) return el.copyWith(zIndex: z);
    if (el is TableElement) return el.copyWith(zIndex: z);
    if (el is ContainerElement) return el.copyWith(zIndex: z);
    return el;
  }

  void updateElement(String id, CanvasElement updated) {
    _elements = updateNodeInTree(_elements, id, updated);
    notifyListeners();
  }

  void commitUpdate(String id, CanvasElement updated) {
    _elements = updateNodeInTree(_elements, id, updated);
    _pushHistory();
    _scheduleAutoSave();
    notifyListeners();
  }

  void deleteElement(String id) {
    _elements = deleteNodeInTree(_elements, id);
    if (_selectedId == id) _selectedId = null;
    if (_selectedChildId == id) _selectedChildId = null;
    _pushHistory();
    _scheduleAutoSave();
    notifyListeners();
  }

  void deleteSelected() {
    if (_selectedChildId != null) {
      _elements = deleteNodeInTree(_elements, _selectedChildId!);
      _selectedChildId = null;
      _pushHistory();
      _scheduleAutoSave();
      notifyListeners();
    } else if (_selectedId != null) {
      deleteElement(_selectedId!);
    }
  }

  void addChildToContainer(String containerId, CanvasElement child) {
    final parent = findNodeInTree(_elements, containerId);
    if (parent is ContainerElement &&
        !canNestLayoutChild(
          parentType: parent.type,
          childType: child.type,
          parentFreePlacement: parent.freePlacement,
          sectionLayoutEnabled: sectionLayoutEnabled,
        )) {
      return;
    }
    _elements = addChildDeep(_elements, containerId, child);
    _selectedChildId = child.id;
    _pushHistory();
    _scheduleAutoSave();
    notifyListeners();
  }

  void bringForward(String id) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final el = _elements[idx];
    final newZ = el.zIndex + 1;
    final updated = _withZIndex(el, newZ);
    _elements = updateNodeInTree(_elements, id, updated);
    _pushHistory();
    _scheduleAutoSave();
    notifyListeners();
  }

  void sendBack(String id) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final el = _elements[idx];
    final newZ = (el.zIndex - 1).clamp(0, 999);
    final updated = _withZIndex(el, newZ);
    _elements = updateNodeInTree(_elements, id, updated);
    _pushHistory();
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Template updates ─────────────────────────────────────────────────────────

  void updateTemplate(Template t) {
    _template = t;
    notifyListeners();
  }

  void updateBackgroundColor(String color) {
    if (_template == null) return;
    _template = _template!.copyWith(backgroundColor: color);
    _scheduleAutoSave();
    notifyListeners();
  }

  /// Returns count of elements that will be partially off-canvas after resize,
  /// without modifying state. Used to show a warning before applying.
  int previewCanvasResize(double newWMm, double newHMm) {
    if (_template == null) return 0;
    final oldWPx = mmToPx(_template!.canvasWidthMm);
    final oldHPx = mmToPx(_template!.canvasHeightMm);
    return _smartRescaleAll(_elements, oldWPx, oldHPx, mmToPx(newWMm), mmToPx(newHMm))
        .offCanvasCount;
  }

  Future<void> applyCanvasResize(double newWMm, double newHMm) async {
    if (_template == null) return;
    final oldWPx = mmToPx(_template!.canvasWidthMm);
    final oldHPx = mmToPx(_template!.canvasHeightMm);
    final newWPx = mmToPx(newWMm);
    final newHPx = mmToPx(newHMm);

    final result = _smartRescaleAll(_elements, oldWPx, oldHPx, newWPx, newHPx);
    _elements = result.elements;

    final key = kCanvasSizes
        .where((s) =>
            (s.widthMm - newWMm).abs() < 0.5 && (s.heightMm - newHMm).abs() < 0.5)
        .map((s) => s.key)
        .firstOrNull ?? 'custom';

    _template = _template!.copyWith(
      canvasWidthMm: newWMm,
      canvasHeightMm: newHMm,
      canvasSize: key,
    );

    _pushHistory();
    await save();
    notifyListeners();
  }

  // ── Smart resize ─────────────────────────────────────────────────────────────

  ({List<CanvasElement> elements, int offCanvasCount}) _smartRescaleAll(
    List<CanvasElement> elements,
    double oldCW, // old canvas px
    double oldCH,
    double newCW, // new canvas px
    double newCH,
  ) {
    int offCount = 0;
    final rescaled = elements.map((e) {
      if (e.isSection || e.x == null || e.y == null) return e;

      final ex = e.x!;
      final ey = e.y!;
      final ew = e.width ?? 100.0;
      final eh = e.height ?? 50.0;

      // Relative measurements (0..1)
      final xRel = ex / oldCW;
      final yRel = ey / oldCH;
      final wRel = ew / oldCW;
      final hRel = eh / oldCH;
      final rightRel = (ex + ew) / oldCW;
      final bottomRel = (ey + eh) / oldCH;

      // ── Horizontal intent ────────────────────────────────────────────────────
      final isFullWidth = wRel > 0.85 && xRel < 0.08;
      final isNearRight = !isFullWidth && rightRel > 0.85 && xRel > 0.35;
      final isCenteredH = !isFullWidth &&
          !isNearRight &&
          (xRel + wRel / 2 - 0.5).abs() < 0.1;

      double newX, newW;
      if (isFullWidth) {
        // Span full new width, preserve proportional left inset
        newX = xRel * newCW;
        newW = newCW - newX;
      } else if (isNearRight) {
        // Anchor to right edge — preserve absolute right margin
        final rightMargin = (oldCW - (ex + ew)) * (newCW / oldCW);
        newW = ew;
        newX = newCW - newW - rightMargin;
        if (newX < 0) {
          // Doesn't fit at absolute size → scale proportionally
          newW = wRel * newCW;
          newX = newCW - newW - (rightMargin.clamp(0, newCW * 0.05));
        }
      } else if (isCenteredH) {
        // Stay centred on canvas, preserve absolute width if it fits
        newW = (ew <= newCW * 0.95) ? ew : wRel * newCW;
        newX = (newCW - newW) / 2;
      } else {
        // Proportional position, preserve absolute size where possible
        newX = xRel * newCW;
        newW = ew;
        if (newX + newW > newCW) {
          newW = (wRel * newCW).clamp(20.0, newCW - newX.clamp(0.0, newCW - 20));
        }
      }

      // ── Vertical intent ──────────────────────────────────────────────────────
      final isFullHeight = hRel > 0.85 && yRel < 0.08;
      final isNearBottom = !isFullHeight && bottomRel > 0.85 && yRel > 0.35;
      final isCenteredV = !isFullHeight &&
          !isNearBottom &&
          (yRel + hRel / 2 - 0.5).abs() < 0.1;

      double newY, newH;
      if (isFullHeight) {
        newY = yRel * newCH;
        newH = newCH - newY;
      } else if (isNearBottom) {
        final bottomMargin = (oldCH - (ey + eh)) * (newCH / oldCH);
        newH = eh;
        newY = newCH - newH - bottomMargin;
        if (newY < 0) {
          newH = hRel * newCH;
          newY = newCH - newH - (bottomMargin.clamp(0, newCH * 0.05));
        }
      } else if (isCenteredV) {
        newH = (eh <= newCH * 0.95) ? eh : hRel * newCH;
        newY = (newCH - newH) / 2;
      } else {
        newY = yRel * newCH;
        newH = eh;
        if (newY + newH > newCH) {
          newH = (hRel * newCH).clamp(10.0, newCH - newY.clamp(0.0, newCH - 10));
        }
      }

      // Clamp positions (allow slight negative to keep edge-hugging elements)
      newX = newX.clamp(-(ew * 0.3), newCW - 10);
      newY = newY.clamp(-(eh * 0.3), newCH - 10);
      newW = newW.clamp(10.0, double.infinity);
      newH = newH.clamp(5.0, double.infinity);

      // Count elements that are mostly off-canvas
      final visR = (newX + newW).clamp(0.0, newCW) - newX.clamp(0.0, newCW);
      final visB = (newY + newH).clamp(0.0, newCH) - newY.clamp(0.0, newCH);
      if (visR < newW * 0.5 || visB < newH * 0.5) offCount++;

      // Font scaling: only scale proportionally for wide text elements
      double? newFontSize;
      if (e is TextElement && wRel > 0.5) {
        final sMin = (newCW / oldCW).clamp(0.4, 2.5);
        newFontSize = (e.fontSize * sMin * 10).round() / 10.0;
      }

      return _applyGeometry(e, newX, newY, newW, newH, newFontSize);
    }).toList();

    return (elements: rescaled, offCanvasCount: offCount);
  }

  CanvasElement _applyGeometry(
      CanvasElement e, double x, double y, double w, double h, double? fontSize) {
    if (e is TextElement) {
      return e.copyWith(x: x, y: y, width: w, height: h, fontSize: fontSize);
    }
    if (e is ShapeElement) return e.copyWith(x: x, y: y, width: w, height: h);
    if (e is ImageElement) return e.copyWith(x: x, y: y, width: w, height: h);
    if (e is QrElement) return e.copyWith(x: x, y: y, width: w, height: h);
    if (e is BarcodeElement) return e.copyWith(x: x, y: y, width: w, height: h);
    if (e is ContainerElement) return e.copyWith(x: x, y: y, width: w, height: h);
    return e;
  }

  // ── History ──────────────────────────────────────────────────────────────────

  void _pushHistory() {
    if (_suppressHistory) return;
    final snap = elementsToJson(_elements);
    final slice = _history.sublist(0, _historyIdx + 1);
    slice.add(snap);
    if (slice.length > _maxHistory) slice.removeAt(0);
    _history.clear();
    _history.addAll(slice);
    _historyIdx = _history.length - 1;
  }

  void undo() {
    if (!canUndo) return;
    _historyIdx--;
    _suppressHistory = true;
    _elements = elementsFromJson(_history[_historyIdx]);
    _suppressHistory = false;
    _selectedId = null;
    _selectedChildId = null;
    _scheduleAutoSave();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    _historyIdx++;
    _suppressHistory = true;
    _elements = elementsFromJson(_history[_historyIdx]);
    _suppressHistory = false;
    _scheduleAutoSave();
    notifyListeners();
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), save);
  }

  Future<void> save() async {
    if (_template == null) return;
    _saving = true;
    notifyListeners();
    final updated = await _storage.save(
      _template!.copyWith(elements: elementsToJson(_elements)),
    );
    _template = updated;
    _saving = false;
    notifyListeners();
    onSaved?.call(updated);
  }

  // ── Snap ─────────────────────────────────────────────────────────────────────

  static const _snapThreshold = 6.0;
  static const _gridSize = 10.0;

  ({double x, double y, List<SnapGuide> guides}) computeSnap({
    required double x,
    required double y,
    required double width,
    required double height,
    required String id,
    required double canvasW,
    required double canvasH,
  }) {
    final vCandidates = <double>[0, canvasW / 2, canvasW];
    final hCandidates = <double>[0, canvasH / 2, canvasH];

    for (final e in _elements) {
      if (e.id == id || e.x == null) continue;
      vCandidates.addAll([e.x!, e.x! + (e.width ?? 0) / 2, e.x! + (e.width ?? 0)]);
      hCandidates.addAll([e.y!, e.y! + (e.height ?? 0) / 2, e.y! + (e.height ?? 0)]);
    }

    double? snapX;
    double bestDx = _snapThreshold;
    final xEdges = [
      (offset: 0.0, val: x),
      (offset: width / 2, val: x + width / 2),
      (offset: width, val: x + width),
    ];
    SnapGuide? xGuide;
    for (final edge in xEdges) {
      for (final c in vCandidates) {
        final dist = (edge.val - c).abs();
        if (dist < bestDx) {
          bestDx = dist;
          snapX = c - edge.offset;
          xGuide = SnapGuide(type: 'v', pos: c);
        }
      }
    }

    double? snapY;
    double bestDy = _snapThreshold;
    final yEdges = [
      (offset: 0.0, val: y),
      (offset: height / 2, val: y + height / 2),
      (offset: height, val: y + height),
    ];
    SnapGuide? yGuide;
    for (final edge in yEdges) {
      for (final c in hCandidates) {
        final dist = (edge.val - c).abs();
        if (dist < bestDy) {
          bestDy = dist;
          snapY = c - edge.offset;
          yGuide = SnapGuide(type: 'h', pos: c);
        }
      }
    }

    double snapToGrid(double v) => (v / _gridPitch).roundToDouble() * _gridPitch;

    final finalX = snapX != null ? snapX!.roundToDouble() : snapToGrid(x);
    final finalY = snapY != null ? snapY!.roundToDouble() : snapToGrid(y);
    final guides = [if (xGuide != null) xGuide, if (yGuide != null) yGuide];

    return (x: finalX, y: finalY, guides: guides);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}
