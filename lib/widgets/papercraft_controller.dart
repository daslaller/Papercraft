import 'package:flutter/foundation.dart';
import '../state/editor_state.dart';

/// Programmatic control handle for [PapercraftEditor].
///
/// Create one, pass it to the editor, then call methods on it from your own UI.
///
/// ```dart
/// final _ctrl = PapercraftController();
///
/// // Pass to editor:
/// PapercraftEditor(
///   templateId: id,
///   controller: _ctrl,
///   onClose: () => Navigator.pop(context),
/// )
///
/// // Drive from your own buttons:
/// IconButton(
///   icon: Icon(Icons.undo),
///   onPressed: _ctrl.canUndo ? _ctrl.undo : null,
/// )
/// ElevatedButton(
///   onPressed: _ctrl.save,
///   child: Text('Save'),
/// )
/// ```
///
/// [PapercraftController] is a [ChangeNotifier] — listen to it to react to
/// state changes (zoom, saving, undo availability) without reading EditorState
/// directly.
class PapercraftController extends ChangeNotifier {
  EditorState? _state;

  // Called by PapercraftEditor — do not call directly.
  // ignore: use_setters_to_change_properties
  void attach(EditorState state) {
    _state?.removeListener(_onStateChange);
    _state = state;
    state.addListener(_onStateChange);
  }

  void detach() {
    _state?.removeListener(_onStateChange);
    _state = null;
  }

  void _onStateChange() => notifyListeners();

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  // ── Read state ─────────────────────────────────────────────────────────────

  /// Whether there is an action to undo.
  bool get canUndo => _state?.canUndo ?? false;

  /// Whether there is an action to redo.
  bool get canRedo => _state?.canRedo ?? false;

  /// Current zoom level (10–200, where 100 = 100%).
  double get zoom => _state?.zoom ?? 100;

  /// True while an auto-save is in progress.
  bool get saving => _state?.saving ?? false;

  /// True when snap-to-grid is enabled.
  bool get snapEnabled => _state?.snapEnabled ?? true;

  /// True when the canvas grid overlay is shown.
  bool get gridEnabled => _state?.gridEnabled ?? false;

  // ── Commands ───────────────────────────────────────────────────────────────

  /// Undo the last canvas action.
  void undo() => _state?.undo();

  /// Redo the last undone action.
  void redo() => _state?.redo();

  /// Zoom in one step.
  void zoomIn() => _state?.zoomIn();

  /// Zoom out one step.
  void zoomOut() => _state?.zoomOut();

  /// Set zoom to an explicit level (10–200).
  void setZoom(double level) => _state?.setZoom(level);

  /// Reset zoom to 100%.
  void resetZoom() => _state?.setZoom(100);

  /// Fit the canvas into the current viewport.
  /// Provide the viewport size in logical pixels (e.g. from LayoutBuilder).
  void fitToView(double viewWidth, double viewHeight) =>
      _state?.fitToView(viewWidth, viewHeight);

  /// Trigger a manual save immediately.
  Future<void> save() async => _state?.save();

  /// Toggle snap-to-grid.
  void toggleSnap() => _state?.toggleSnap();

  /// Toggle grid overlay.
  void toggleGrid() => _state?.toggleGrid();

  /// Delete the currently selected element.
  void deleteSelected() => _state?.deleteSelected();

  /// Deselect all elements.
  void deselect() => _state?.deselect();

  /// Enable or disable pan mode.
  void setPanMode(bool enabled) => _state?.setPanMode(enabled);
}
