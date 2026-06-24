import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/element_model.dart';
import '../../models/template_model.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import 'canvas_element_widget.dart';
import 'element_renderer.dart';

class CanvasWorkspace extends StatefulWidget {
  const CanvasWorkspace({super.key});

  @override
  State<CanvasWorkspace> createState() => _CanvasWorkspaceState();
}

class _CanvasWorkspaceState extends State<CanvasWorkspace> {
  final _workspaceKey = GlobalKey();
  bool _isPanning = false;
  Offset _panStart = Offset.zero;
  Offset _panOffsetStart = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final template = state.template;
    if (template == null) return const SizedBox.expand();

    final canvasW = mmToPx(template.canvasWidthMm);
    final canvasH = mmToPx(template.canvasHeightMm);
    final scale = state.zoom / 100;

    return Focus(
      autofocus: true,
      onKeyEvent: (_, e) => _handleKey(e, state),
      child: Listener(
        onPointerDown: (e) => _onPointerDown(e, state),
        onPointerMove: (e) => _onPointerMove(e, state),
        onPointerUp: (e) => _onPointerUp(e, state),
        onPointerSignal: (e) => _onScroll(e, state),
        child: GestureDetector(
          onTap: () => state.deselect(),
          child: Container(
            key: _workspaceKey,
            color: AppColors.workspaceBg,
            child: CustomPaint(
              painter: _DotGridPainter(),
              child: Stack(children: [
                // Canvas container — ClipRect + OverflowBox prevents layout
                // breakage at any zoom level while still allowing pan overflow.
                Positioned.fill(
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        offset: state.panOffset,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: SizedBox(
                              width: canvasW * scale,
                              height: canvasH * scale,
                              child: Transform.scale(
                                scale: scale,
                                alignment: Alignment.topLeft,
                                child: _buildCanvas(state, template, canvasW, canvasH),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(
      EditorState state, Template template, double canvasW, double canvasH) {
    final bg = template.backgroundColor;
    Color bgColor;
    try {
      bgColor = Color(int.parse('FF${bg.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      bgColor = Colors.white;
    }

    // Sort elements by zIndex
    final absSorted = state.elements
        .where((e) => !e.isSection && e.x != null)
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final sections =
        state.elements.where((e) => e.isSection).toList();

    return Container(
      width: canvasW,
      height: canvasH,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: AppColors.shadowCanvas,
        borderRadius: BorderRadius.circular(2),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Grid overlay
          if (state.gridEnabled)
            Positioned.fill(
              child: CustomPaint(painter: _CanvasGridPainter(pitch: state.gridPitch)),
            ),

          // Sections at top
          if (sections.isNotEmpty)
            Positioned(
              top: 0, left: 0, right: 0,
              child: Column(
                children: sections.map((e) =>
                  _buildSectionContainer(e as ContainerElement, state)).toList(),
              ),
            ),

          // Absolute elements
          ...absSorted.map((e) => CanvasElementWidget(
            key: ValueKey(e.id),
            el: e,
            selected: state.selectedId == e.id,
            scale: state.zoom / 100,
            snapEnabled: state.snapEnabled,
            canvasW: canvasW,
            canvasH: canvasH,
            allElements: state.elements,
            previewRecord: state.previewMode ? state.previewRecord : null,
            previewEntityName: state.previewMode ? state.previewEntityName : null,
            onUpdate: (updated) => state.updateElement(e.id, updated),
            onCommit: (updated) => state.commitUpdate(e.id, updated),
            onSelect: () => state.select(e.id),
            onSnapGuides: (guides) => state.setSnapGuides(guides),
          )),

          // Snap guides
          ...state.snapGuides.map((g) => g.type == 'v'
              ? Positioned(
                  left: g.pos,
                  top: 0,
                  bottom: 0,
                  child: Container(
                      width: 1, color: AppColors.accent),
                )
              : Positioned(
                  top: g.pos,
                  left: 0,
                  right: 0,
                  child: Container(
                      height: 1, color: AppColors.accent),
                )),

          // Canvas size label
          Positioned(
            bottom: -28,
            left: 0,
            right: 0,
            child: Text(
              '${template.canvasSize} · ${template.canvasWidthMm.toStringAsFixed(0)}×${template.canvasHeightMm.toStringAsFixed(0)} mm',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0x59000000),
                  fontFamily: 'sans-serif'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer(ContainerElement e, EditorState state) {
    final selected = state.selectedId == e.id;
    return GestureDetector(
      onTap: () => state.select(e.id),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: e.minHeight),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? withAlpha(AppColors.foreground, 0.7)
                : const Color(0x1A000000),
            width: selected ? 1.5 : 1,
            style: selected ? BorderStyle.solid : BorderStyle.none,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            IgnorePointer(
              child: ElementRenderer(
                el: e,
                record: state.previewMode ? state.previewRecord : null,
                entityName:
                    state.previewMode ? state.previewEntityName : null,
                showTokenChips: !state.previewMode,
              ),
            ),
            Positioned(
              top: 2,
              right: 4,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xB3FFFFFF),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    e.type == 'row' ? 'ROW' : 'COL',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0x40000000),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Input handling ────────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent e, EditorState state) {
    // Middle-click always pans. Left-click pans only when pan mode is on
    // AND no element has already claimed this pointer down event.
    // Child Listener (CanvasElementWidget) fires before parent, so
    // elementDragActive is set to true before we get here.
    final isPanGesture = e.buttons == 4 ||
        (state.panMode && !state.elementDragActive);
    if (isPanGesture) {
      _isPanning = true;
      _panStart = e.position;
      _panOffsetStart = state.panOffset;
    }
  }

  void _onPointerMove(PointerMoveEvent e, EditorState state) {
    if (_isPanning) {
      state.setPanOffset(_panOffsetStart + (e.position - _panStart));
    }
  }

  void _onPointerUp(PointerUpEvent e, EditorState state) {
    _isPanning = false;
    state.endElementDrag(); // safety reset if element drag ended without cleanup
  }

  void _onScroll(PointerSignalEvent e, EditorState state) {
    if (e is PointerScrollEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isCtrl) {
        if (e.scrollDelta.dy < 0) {
          state.zoomIn();
        } else {
          state.zoomOut();
        }
      }
    }
  }

  // ignore unused: PointerScrollEvent is from gestures package

  KeyEventResult _handleKey(KeyEvent e, EditorState state) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;

    final focused = FocusManager.instance.primaryFocus;
    if (focused?.context?.widget is EditableText) {
      return KeyEventResult.ignored;
    }

    final isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (e.logicalKey == LogicalKeyboardKey.space) {
      state.setPanMode(true);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.delete ||
        e.logicalKey == LogicalKeyboardKey.backspace) {
      state.deleteSelected();
      return KeyEventResult.handled;
    }
    if (isCtrl && !isShift && e.logicalKey == LogicalKeyboardKey.keyZ) {
      state.undo();
      return KeyEventResult.handled;
    }
    if ((isCtrl && isShift && e.logicalKey == LogicalKeyboardKey.keyZ) ||
        (isCtrl && e.logicalKey == LogicalKeyboardKey.keyY)) {
      state.redo();
      return KeyEventResult.handled;
    }
    if (isCtrl && e.logicalKey == LogicalKeyboardKey.keyS) {
      state.save();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.keyG) {
      state.toggleGrid();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.keyS) {
      state.toggleSnap();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.equal ||
        e.logicalKey == LogicalKeyboardKey.add) {
      state.zoomIn();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.minus) {
      state.zoomOut();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x24000000);
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CanvasGridPainter extends CustomPainter {
  final double pitch;
  const _CanvasGridPainter({this.pitch = 10});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x1F000000);
    for (double x = 0; x < size.width; x += pitch) {
      for (double y = 0; y < size.height; y += pitch) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CanvasGridPainter old) => old.pitch != pitch;
}
