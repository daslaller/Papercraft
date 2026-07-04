import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/element_model.dart';
import '../models/template_model.dart';
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
import '../services/papercraft_storage.dart';
import 'papercraft_controller.dart';
import 'papercraft_data_source.dart';
import 'papercraft_renderer.dart';

export 'papercraft_data_source.dart';
export 'papercraft_controller.dart';

/// Self-contained label/document editor widget.
///
/// No dependency on GoRouter or any particular navigation setup.
///
/// ```dart
/// import 'package:base44_flutter_label_creator/papercraft.dart';
///
/// // Minimal — full editor, no data injection:
/// PapercraftEditor(
///   templateId: template.id,
///   onClose: () => Navigator.pop(context),
/// )
///
/// // With live data from your app:
/// PapercraftEditor(
///   templateId: template.id,
///   dataSource: PapercraftDataSource(
///     entityName: 'work_order',
///     fields: {
///       'work_order.number': 'WO-4821',
///       'customer.name':     'Jane Doe',
///       'device.model':      'iPhone 15',
///     },
///   ),
///   mode: PapercraftMode.edit,
///   onSave:  (t) => myState.onTemplateSaved(t),
///   onPrint: (t, record) => analytics.logPrint(t.id),
///   onClose: () => Navigator.pop(context),
/// )
///
/// // Read-only preview of a filled record:
/// PapercraftEditor(
///   templateId: template.id,
///   dataSource: dataSource,
///   mode: PapercraftMode.preview,
/// )
///
/// // Jump straight to print dialog:
/// PapercraftEditor(
///   templateId: template.id,
///   dataSource: dataSource,
///   mode: PapercraftMode.printReady,
///   onClose: () => Navigator.pop(context),
/// )
/// ```
class PapercraftEditor extends StatefulWidget {
  final String templateId;

  /// Live data record to inject into the canvas.
  ///
  /// When provided the left data-source sidebar is hidden (your app is the
  /// source of truth). When null the built-in adapter/sidebar is shown.
  final PapercraftDataSource? dataSource;

  /// Starting mode. Defaults to [PapercraftMode.edit].
  final PapercraftMode mode;

  /// Called when the user presses ← in the toolbar, or when the editor
  /// closes itself (e.g. template not found). If null the back button is
  /// hidden. Defaults to [Navigator.maybePop] when set to a no-op.
  final VoidCallback? onClose;

  /// Called after every save (auto-save + manual save triggered from
  /// print preview). Receives the updated [Template].
  final void Function(Template template)? onSave;

  /// Called after the user confirms a print. Receives the template and the
  /// flat record that was used to fill tokens.
  final void Function(Template template, Map<String, dynamic> record)? onPrint;

  /// Optional controller for programmatic undo/redo/zoom/save.
  ///
  /// ```dart
  /// final _ctrl = PapercraftController();
  /// PapercraftEditor(templateId: id, controller: _ctrl)
  /// // then: _ctrl.undo(), _ctrl.save(), etc.
  /// ```
  final PapercraftController? controller;

  /// Custom template storage back-end.
  ///
  /// Defaults to [StorageRegistry.active] (SharedPreferences unless you've
  /// called [StorageRegistry.register]).
  final PapercraftStorage? storage;

  /// Show the right properties panel. Defaults to true.
  /// Set false if you embed the editor alongside your own property UI.
  final bool showPropertiesPanel;

  const PapercraftEditor({
    super.key,
    required this.templateId,
    this.dataSource,
    this.mode = PapercraftMode.edit,
    this.onClose,
    this.onSave,
    this.onPrint,
    this.controller,
    this.storage,
    this.showPropertiesPanel = true,
  });

  @override
  State<PapercraftEditor> createState() => _PapercraftEditorState();
}

class _PapercraftEditorState extends State<PapercraftEditor> {
  late EditorState _state;
  bool _loading = true;
  bool _error = false;
  bool _rightOpen = true;

  @override
  void initState() {
    super.initState();
    _state = EditorState();
    _load();
  }

  PapercraftStorage get _storage => widget.storage ?? StorageRegistry.active;

  Future<void> _load() async {
    // Use the provided storage to load; fall back to EditorState.load which
    // uses TemplateService (SharedPrefs) if no custom storage given.
    if (widget.storage != null) {
      final template = await _storage.getById(widget.templateId);
      if (template != null) {
        _state.loadFromTemplate(template);
      }
    } else {
      await _state.load(widget.templateId);
    }
    if (!mounted) return;

    if (_state.template == null) {
      setState(() { _loading = false; _error = true; });
      return;
    }

    // Inject caller-supplied data source into EditorState so tokens resolve
    // on the canvas using the host app's live record.
    final ds = widget.dataSource;
    if (ds != null) {
      _state.setPreviewRecord(ds.fields, ds.entityName);
      _state.setPreviewMode(true);
    }

    // Attach controller if provided.
    widget.controller?.attach(_state);

    setState(() => _loading = false);

    // printReady: open print dialog as soon as the template is ready.
    if (widget.mode == PapercraftMode.printReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPrintPreview();
      });
    }
  }

  @override
  void didUpdateWidget(PapercraftEditor old) {
    super.didUpdateWidget(old);
    // Re-inject if the caller swaps the record (e.g. user picks a different
    // work order while the editor is still mounted).
    final ds = widget.dataSource;
    if (ds != null && ds != old.dataSource) {
      _state.setPreviewRecord(ds.fields, ds.entityName);
      _state.setPreviewMode(true);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _state.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.of(context).maybePop();
    }
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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Template not found.',
                style: TextStyle(color: AppColors.foreground)),
            if (widget.onClose != null)
              TextButton(onPressed: _close, child: const Text('Go back')),
          ]),
        ),
      );
    }

    // preview mode: show read-only renderer, no editor chrome.
    if (widget.mode == PapercraftMode.preview) {
      return ChangeNotifierProvider.value(
        value: _state,
        child: ColoredBox(
          color: AppColors.workspaceBg,
          child: Center(
            child: PapercraftRenderer.fitted(
              template: _state.template!,
              elements: _state.elements,
              record: widget.dataSource?.fields,
              entityName: widget.dataSource?.entityName,
              computedFields: widget.dataSource?.computedFields ?? const [],
            ),
          ),
        ),
      );
    }

    // edit / printReady: full editor UI.
    // When dataSource is provided the left sidebar (adapter picker) is hidden —
    // the host app owns the record.
    final showDataSidebar = widget.dataSource == null;

    return ChangeNotifierProvider.value(
      value: _state,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(children: [
          EditorToolbar(
            onBack: widget.onClose != null ? _close : () {},
            onPreview: _openPreview,
            onExportPdf: _openPrintPreview,
          ),
          Expanded(
            child: Row(children: [
              if (showDataSidebar)
                _AnimatedSidebar(
                  child: LeftSidebar(onClose: () {}),
                ),
              Expanded(
                child: Stack(children: [
                  const CanvasWorkspace(),
                  ViewportNav(onPrint: _openPrintPreview),
                  if (widget.showPropertiesPanel && !_rightOpen)
                    Positioned(
                      right: 12, top: 12,
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
    final record = widget.dataSource?.fields ?? _state.previewRecord ?? {};

    showDialog(
      context: context,
      builder: (_) => PrintPreviewModal(
        template: template,
        elements: elements,
        onPrinterSelected: (printerName) async {
          final updated = template.copyWith(
            printerName: printerName,
            clearPrinter: printerName == null,
          );
          await TemplateService.update(updated);
          _state.updateTemplate(updated);
          widget.onSave?.call(updated);
          widget.onPrint?.call(updated, record);
        },
      ),
    );
  }
}

class _AnimatedSidebar extends StatefulWidget {
  final Widget child;
  const _AnimatedSidebar({required this.child});

  @override
  State<_AnimatedSidebar> createState() => _AnimatedSidebarState();
}

class _AnimatedSidebarState extends State<_AnimatedSidebar> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      child: SizedBox(
        width: _open ? null : 0,
        child: ClipRect(
          child: LeftSidebar(
            onClose: () => setState(() => _open = false),
          ),
        ),
      ),
    );
  }
}
