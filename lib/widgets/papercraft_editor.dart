import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/element_model.dart';
import '../services/template_service.dart';
import '../state/editor_state.dart';
import '../theme/app_colors.dart';
import 'editor/canvas_workspace.dart';
import 'editor/editor_bottom_bar.dart';
import 'editor/left_sidebar.dart';
import 'editor/right_sidebar.dart';
import 'editor/sidebar_utils.dart';
import 'editor/toolbar.dart';
import 'editor/viewport_nav.dart';
import 'modals/preview_modal.dart';
import 'modals/print_preview_modal.dart';

/// Self-contained label/document editor widget for embedding in any Flutter app.
///
/// Unlike [EditorScreen], this widget has **no dependency on GoRouter** or any
/// particular navigation setup. Drop it anywhere in your widget tree:
///
/// ```dart
/// import 'package:base44_flutter_label_creator/papercraft.dart';
///
/// // Fullscreen page:
/// Navigator.push(context, MaterialPageRoute(
///   builder: (_) => Scaffold(
///     body: PapercraftEditor(templateId: id, onClose: () => Navigator.pop(context)),
///   ),
/// ));
///
/// // Embedded inside a larger layout:
/// Row(children: [
///   MySidebar(),
///   Expanded(child: PapercraftEditor(templateId: id)),
/// ]);
/// ```
class PapercraftEditor extends StatefulWidget {
  final String templateId;

  /// Called when the user presses the ← back button in the editor toolbar.
  /// If null the button is hidden.
  final VoidCallback? onClose;

  /// Called after every auto-save with the updated template id.
  /// Useful if the host app wants to react to saves (e.g. refresh a list).
  final void Function(String templateId)? onSaved;

  /// Whether to show the left data-source sidebar. Defaults to true.
  final bool showDataSidebar;

  /// Whether to show the right properties panel. Defaults to true.
  final bool showPropertiesPanel;

  const PapercraftEditor({
    super.key,
    required this.templateId,
    this.onClose,
    this.onSaved,
    this.showDataSidebar = true,
    this.showPropertiesPanel = true,
  });

  @override
  State<PapercraftEditor> createState() => _PapercraftEditorState();
}

class _PapercraftEditorState extends State<PapercraftEditor> {
  late EditorState _state;
  bool _loading = true;
  bool _error = false;
  bool _leftOpen = true;
  bool _rightOpen = true;

  @override
  void initState() {
    super.initState();
    _state = EditorState();
    _load();
  }

  Future<void> _load() async {
    await _state.load(widget.templateId);
    if (!mounted) return;
    if (_state.template == null) {
      setState(() { _loading = false; _error = true; });
      return;
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error) {
      return ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Template not found.',
                  style: TextStyle(color: AppColors.foreground)),
              if (widget.onClose != null)
                TextButton(onPressed: widget.onClose, child: const Text('Go back')),
            ],
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _state,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          children: [
            EditorToolbar(
              onBack: widget.onClose ?? () {},
              onPreview: _openPreview,
              onExportPdf: _openPrintPreview,
            ),
            Expanded(
              child: Row(children: [
                if (widget.showDataSidebar)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      width: _leftOpen ? null : 0,
                      child: ClipRect(
                        child: LeftSidebar(
                          onClose: () => setState(() => _leftOpen = false),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(children: [
                    const CanvasWorkspace(),
                    ViewportNav(onPrint: _openPrintPreview),
                    if (widget.showDataSidebar && !_leftOpen)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: FloatingSidebarPill(
                          icon: Icons.data_object_outlined,
                          onTap: () => setState(() => _leftOpen = true),
                        ),
                      ),
                    if (widget.showPropertiesPanel && !_rightOpen)
                      Positioned(
                        right: 12,
                        top: 12,
                        child: FloatingSidebarPill(
                          icon: Icons.tune,
                          onTap: () => setState(() => _rightOpen = true),
                        ),
                      ),
                  ]),
                ),
                if (widget.showPropertiesPanel)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      width: _rightOpen ? null : 0,
                      child: ClipRect(
                        child: RightSidebar(
                          onClose: () => setState(() => _rightOpen = false),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const EditorBottomBar(),
          ],
        ),
      ),
    );
  }

  void _openPreview() {
    showDialog(
      context: context,
      builder: (_) => PreviewModal(
        template: _state.template!,
        elements: _state.elements,
      ),
    );
  }

  void _openPrintPreview() {
    final template = _state.template!;
    final elements = List<CanvasElement>.from(_state.elements);
    showDialog(
      context: context,
      builder: (_) => PrintPreviewModal(
        template: template,
        elements: elements,
        onPrinterSelected: (printerName) async {
          final updated = template.copyWith(
              printerName: printerName, clearPrinter: printerName == null);
          await TemplateService.update(updated);
          _state.updateTemplate(updated);
          widget.onSaved?.call(widget.templateId);
        },
      ),
    );
  }
}
