import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/element_model.dart';
import '../services/papercraft_storage.dart';
import '../services/printer_provider.dart';
import '../state/editor_state.dart';
import '../theme/app_colors.dart';
import '../widgets/editor/canvas_workspace.dart';
import '../widgets/editor/editor_bottom_bar.dart';
import '../widgets/editor/left_sidebar.dart';
import '../widgets/editor/right_sidebar.dart';
import '../widgets/editor/sidebar_utils.dart';
import '../widgets/editor/toolbar.dart';
import '../widgets/editor/viewport_nav.dart';
import '../widgets/modals/preview_modal.dart';
import '../widgets/modals/print_preview_modal.dart';

class EditorScreen extends StatefulWidget {
  final String templateId;

  /// Called when the user presses the back/close button in the toolbar.
  /// Defaults to [Navigator.maybePop] so it works without GoRouter.
  /// Pass `() => context.go('/')` when using this inside the app's own router.
  final VoidCallback? onBack;

  const EditorScreen({super.key, required this.templateId, this.onBack});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late EditorState _state;
  bool _loading = true;
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
      _goBack();
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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider.value(
      value: _state,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(children: [
          EditorToolbar(
            onBack: _goBack,
            onPreview: _openPreview,
            onExportPdf: _openPrintPreview,
          ),
          Expanded(
            child: Row(children: [
              // Left sidebar — collapses to zero width with animation.
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
              // Canvas
              Expanded(
                child: Stack(children: [
                  const CanvasWorkspace(),
                  ViewportNav(onPrint: _openPrintPreview),
                  // Floating reopen pills when a sidebar is collapsed
                  if (!_leftOpen)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: FloatingSidebarPill(
                        icon: Icons.data_object_outlined,
                        onTap: () => setState(() => _leftOpen = true),
                      ),
                    ),
                  if (!_rightOpen)
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
              // Right sidebar — collapses to zero width with animation.
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
        ]),
      ),
    );
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
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
        onPrinterSelected: (PapercraftPrinter? printer) async {
          final updated = template.copyWith(
            printerName: printer?.name,
            printerId: printer?.id,
            clearPrinter: printer == null,
          );
          final saved = await StorageRegistry.active.save(updated);
          _state.updateTemplate(saved);
        },
      ),
    );
  }
}
