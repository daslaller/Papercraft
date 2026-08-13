import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/element_model.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import 'element_renderer.dart';

class CanvasElementWidget extends StatefulWidget {
  final CanvasElement el;
  final bool selected;
  final double scale;
  final bool snapEnabled;
  final void Function(CanvasElement) onUpdate;
  final void Function(CanvasElement) onCommit;
  final void Function() onSelect;
  final void Function(List<SnapGuide>) onSnapGuides;
  final double canvasW;
  final double canvasH;
  final List<CanvasElement> allElements;
  final Map<String, dynamic>? previewRecord;
  final String? previewEntityName;

  const CanvasElementWidget({
    super.key,
    required this.el,
    required this.selected,
    required this.scale,
    required this.snapEnabled,
    required this.onUpdate,
    required this.onCommit,
    required this.onSelect,
    required this.onSnapGuides,
    required this.canvasW,
    required this.canvasH,
    required this.allElements,
    this.previewRecord,
    this.previewEntityName,
  });

  @override
  State<CanvasElementWidget> createState() => _CanvasElementWidgetState();
}

class _CanvasElementWidgetState extends State<CanvasElementWidget> {
  bool _editing = false;
  final _textCtrl = TextEditingController();

  // Drag state
  double? _startMx, _startMy, _startX, _startY;
  // Resize state
  double? _rStartMx, _rStartMy, _rStartX, _rStartY, _rStartW, _rStartH;
  double? _rDx, _rDy;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  CanvasElement get el => widget.el;

  double get elX => el.x ?? 0;
  double get elY => el.y ?? 0;
  double get elW => el.width ?? 120;
  double get elH => el.height ?? 80;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: elX,
      top: elY,
      child: Transform.rotate(
        angle: el.rotation * 3.14159265358979 / 180,
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onTap: () {
            widget.onSelect();
          },
          onDoubleTap: el.type == 'text' && !_editing
              ? () {
                  _textCtrl.text = (el as TextElement).content;
                  setState(() => _editing = true);
                }
              : null,
          child: MouseRegion(
            cursor: _editing
                ? SystemMouseCursors.text
                : SystemMouseCursors.move,
            child: Listener(
              onPointerDown: _editing ? null : _onPointerDown,
              child: Opacity(
                opacity: el.opacity,
                child: SizedBox(
                  width: elW,
                  height: elH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Hover/selection outline
                      Container(
                        width: elW,
                        height: elH,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: widget.selected
                                ? withAlpha(AppColors.foreground, 0.7)
                                : withAlpha(AppColors.foreground, 0.2),
                            width: widget.selected ? 1.5 : 1,
                            style: widget.selected
                                ? BorderStyle.solid
                                : BorderStyle.none, // Hover uses CSS-like dashed
                          ),
                        ),
                      ),
                      // Content
                      if (_editing && el is TextElement)
                        _buildEditingTextArea()
                      else
                        IgnorePointer(
                          child: ElementRenderer(
                            el: el,
                            record: widget.previewRecord,
                            entityName: widget.previewEntityName,
                            showTokenChips: widget.previewRecord == null,
                          ),
                        ),
                      // Resize handles
                      if (widget.selected && !_editing)
                        ..._buildHandles(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditingTextArea() {
    final e = el as TextElement;
    return SizedBox(
      width: elW,
      height: elH,
      child: TextField(
        controller: _textCtrl,
        autofocus: true,
        maxLines: null,
        expands: true,
        style: textStyleFrom(e).copyWith(color: hexToFlutter(e.color)),
        textAlign: parseTextAlign(e.textAlign),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onEditingComplete: _commitText,
      ),
    );
  }

  void _commitText() {
    if (el is TextElement) {
      final updated = (el as TextElement).copyWith(content: _textCtrl.text);
      widget.onCommit(updated);
    }
    setState(() => _editing = false);
  }

  // ── Dragging ────────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e) {
    if (e.buttons != 1) return; // Left button only
    widget.onSelect();

    // Tell workspace pan to stand down — this pointer is an element drag.
    // Child Listeners fire before parent, so this is set before the workspace
    // checks elementDragActive in its own onPointerDown handler.
    final editorState = context.read<EditorState>();
    editorState.startElementDrag();

    _startMx = e.position.dx;
    _startMy = e.position.dy;
    _startX = elX;
    _startY = elY;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: _onDragMove,
      onPointerUp: (_) {
        _onDragEnd();
        editorState.endElementDrag();
        entry.remove();
      },
      child: const SizedBox.expand(),
    ));
    overlay.insert(entry);
  }

  void _onDragMove(PointerMoveEvent e) {
    if (_startMx == null) return;
    final editorState = context.read<EditorState>();
    // Keep the document reachable — pan viewport when near edges.
    final panBefore = editorState.panOffset;
    editorState.autoPanForGlobalPointer(e.position);
    final panDelta = editorState.panOffset - panBefore;
    if (panDelta != Offset.zero) {
      // Compensate so the dragged element stays under the cursor after pan.
      _startX = _startX! - panDelta.dx / widget.scale;
      _startY = _startY! - panDelta.dy / widget.scale;
    }

    final dx = (e.position.dx - _startMx!) / widget.scale;
    final dy = (e.position.dy - _startMy!) / widget.scale;
    var nx = _startX! + dx;
    var ny = _startY! + dy;

    List<SnapGuide> guides = [];
    if (widget.snapEnabled) {
      final snapped = _snap(nx, ny, elW, elH);
      nx = snapped.x;
      ny = snapped.y;
      guides = snapped.guides;
    }

    widget.onSnapGuides(guides);

    final updated = _withPos(el, nx.roundToDouble(), ny.roundToDouble());
    widget.onUpdate(updated);
  }

  void _onDragEnd() {
    if (_startMx == null) return;
    _startMx = null;
    widget.onSnapGuides([]);
    widget.onCommit(el); // Commit current position
  }

  // ── Resize ──────────────────────────────────────────────────────────────────

  void _startResize(PointerDownEvent e, double dx, double dy) {
    e.stopPropagation = true;
    _rStartMx = e.position.dx;
    _rStartMy = e.position.dy;
    _rStartX = elX;
    _rStartY = elY;
    _rStartW = elW;
    _rStartH = elH;
    _rDx = dx;
    _rDy = dy;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(builder: (_) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: _onResizeMove,
      onPointerUp: (_) {
        widget.onCommit(el);
        entry.remove();
      },
      child: const SizedBox.expand(),
    ));
    overlay.insert(entry);
  }

  void _onResizeMove(PointerMoveEvent e) {
    if (_rStartMx == null) return;
    final dmx = (e.position.dx - _rStartMx!) / widget.scale;
    final dmy = (e.position.dy - _rStartMy!) / widget.scale;
    final nw = (_rStartW! + dmx * _rDx!).clamp(20, 9999);
    final nh = (_rStartH! + dmy * _rDy!).clamp(20, 9999);
    final nx = _rStartX! + (_rDx! < 0 ? _rStartW! - nw : 0);
    final ny = _rStartY! + (_rDy! < 0 ? _rStartH! - nh : 0);

    final updated = _withGeom(
        el, nx.roundToDouble(), ny.roundToDouble(),
        nw.roundToDouble(), nh.roundToDouble());
    widget.onUpdate(updated);
  }

  List<Widget> _buildHandles() {
    const handles = [
      (hx: -4.0, hy: -4.0, dx: -1.0, dy: -1.0, cursor: SystemMouseCursors.resizeUpLeft),
      (hx: -4.0, hy: -4.0, dx: 0.0, dy: -1.0, cursor: SystemMouseCursors.resizeUp), // top center
      (hx: -4.0, hy: -4.0, dx: 1.0, dy: -1.0, cursor: SystemMouseCursors.resizeUpRight),
      (hx: -4.0, hy: -4.0, dx: 1.0, dy: 0.0, cursor: SystemMouseCursors.resizeRight),
      (hx: -4.0, hy: -4.0, dx: 1.0, dy: 1.0, cursor: SystemMouseCursors.resizeDownRight),
      (hx: -4.0, hy: -4.0, dx: 0.0, dy: 1.0, cursor: SystemMouseCursors.resizeDown),
      (hx: -4.0, hy: -4.0, dx: -1.0, dy: 1.0, cursor: SystemMouseCursors.resizeDownLeft),
      (hx: -4.0, hy: -4.0, dx: -1.0, dy: 0.0, cursor: SystemMouseCursors.resizeLeft),
    ];

    final positions = [
      Offset(-4, -4),               // nw
      Offset(elW / 2 - 4, -4),      // n
      Offset(elW - 4, -4),          // ne
      Offset(elW - 4, elH / 2 - 4), // e
      Offset(elW - 4, elH - 4),     // se
      Offset(elW / 2 - 4, elH - 4), // s
      Offset(-4, elH - 4),          // sw
      Offset(-4, elH / 2 - 4),      // w
    ];

    return List.generate(8, (i) {
      final h = handles[i];
      final pos = positions[i];
      return Positioned(
        left: pos.dx,
        top: pos.dy,
        child: MouseRegion(
          cursor: h.cursor,
          child: Listener(
            onPointerDown: (e) => _startResize(e, h.dx, h.dy),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(
                    color: withAlpha(AppColors.foreground, 0.6), width: 1.5),
                borderRadius: BorderRadius.circular(100),
                boxShadow: AppColors.shadowSm,
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── Snap helper ──────────────────────────────────────────────────────────────

  ({double x, double y, List<SnapGuide> guides}) _snap(
      double x, double y, double w, double h) {
    const threshold = 6.0;
    const gridSize = 10.0;

    final vCandidates = <double>[0, widget.canvasW / 2, widget.canvasW];
    final hCandidates = <double>[0, widget.canvasH / 2, widget.canvasH];
    for (final other in widget.allElements) {
      if (other.id == el.id || other.x == null) continue;
      final ox = other.x!, oy = other.y!, ow = other.width ?? 0, oh = other.height ?? 0;
      vCandidates.addAll([ox, ox + ow / 2, ox + ow]);
      hCandidates.addAll([oy, oy + oh / 2, oy + oh]);
    }

    double? snapX, snapY;
    double bestDx = threshold, bestDy = threshold;
    SnapGuide? xGuide, yGuide;

    for (final c in vCandidates) {
      for (final (off, val) in [(0.0, x), (w / 2, x + w / 2), (w, x + w)]) {
        final d = (val - c).abs();
        if (d < bestDx) { bestDx = d; snapX = c - off; xGuide = SnapGuide(type: 'v', pos: c); }
      }
    }
    for (final c in hCandidates) {
      for (final (off, val) in [(0.0, y), (h / 2, y + h / 2), (h, y + h)]) {
        final d = (val - c).abs();
        if (d < bestDy) { bestDy = d; snapY = c - off; yGuide = SnapGuide(type: 'h', pos: c); }
      }
    }

    snapToGrid(double v) => (v / gridSize).roundToDouble() * gridSize;
    final fx = snapX?.roundToDouble() ?? snapToGrid(x);
    final fy = snapY?.roundToDouble() ?? snapToGrid(y);
    return (x: fx, y: fy, guides: [if (xGuide != null) xGuide!, if (yGuide != null) yGuide!]);
  }
}

CanvasElement _withPos(CanvasElement el, double x, double y) {
  if (el is TextElement) return el.copyWith(x: x, y: y);
  if (el is ShapeElement) return el.copyWith(x: x, y: y);
  if (el is ImageElement) return el.copyWith(x: x, y: y);
  if (el is QrElement) return el.copyWith(x: x, y: y);
  if (el is BarcodeElement) return el.copyWith(x: x, y: y);
  if (el is TableElement) return el.copyWith(x: x, y: y);
  if (el is ContainerElement) return el.copyWith(x: x, y: y);
  return el;
}

CanvasElement _withGeom(CanvasElement el, double x, double y, double w, double h) {
  if (el is TextElement) return el.copyWith(x: x, y: y, width: w, height: h);
  if (el is ShapeElement) return el.copyWith(x: x, y: y, width: w, height: h);
  if (el is ImageElement) return el.copyWith(x: x, y: y, width: w, height: h);
  if (el is QrElement) return el.copyWith(x: x, y: y, width: w, height: h);
  if (el is BarcodeElement) return el.copyWith(x: x, y: y, width: w, height: h);
  if (el is TableElement) return el.copyWith(x: x, y: y, width: w, height: h);
  if (el is ContainerElement) return el.copyWith(x: x, y: y, width: w, height: h);
  return el;
}

extension _StopProp on PointerDownEvent {
  bool get stopPropagation => false;
  set stopPropagation(bool _) {}
}
