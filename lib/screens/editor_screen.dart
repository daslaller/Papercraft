import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/element_model.dart';
import '../services/template_service.dart';
import '../state/editor_state.dart';
import '../theme/app_colors.dart';
import '../widgets/editor/canvas_workspace.dart';
import '../widgets/editor/editor_bottom_bar.dart';
import '../widgets/editor/left_sidebar.dart';
import '../widgets/editor/right_sidebar.dart';
import '../widgets/editor/toolbar.dart';
import '../widgets/editor/viewport_nav.dart';
import '../widgets/modals/preview_modal.dart';
import '../widgets/modals/print_preview_modal.dart';

class EditorScreen extends StatefulWidget {
  final String templateId;

  const EditorScreen({super.key, required this.templateId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late EditorState _state;
  bool _loading = true;

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
      context.go('/');
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
            onBack: () => context.go('/'),
            onPreview: _openPreview,
            onExportPdf: _openPrintPreview,
          ),
          Expanded(
            child: Row(children: [
              const LeftSidebar(),
              Expanded(
                child: Stack(children: [
                  const CanvasWorkspace(),
                  ViewportNav(onPrint: _openPrintPreview),
                ]),
              ),
              const RightSidebar(),
            ]),
          ),
          const EditorBottomBar(),
        ]),
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
          final updated = template.copyWith(printerName: printerName, clearPrinter: printerName == null);
          await TemplateService.update(updated);
          _state.updateTemplate(updated);
        },
      ),
    );
  }
}
