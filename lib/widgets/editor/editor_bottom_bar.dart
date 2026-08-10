import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/template_model.dart';
import '../../services/paper_size_service.dart';
import '../../services/printer_provider.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import '../common/paper_chrome.dart';

class EditorBottomBar extends StatefulWidget {
  const EditorBottomBar({super.key});

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  List<PapercraftPrinter> _printers = [];
  List<CustomPaperSize> _customSizes = [];
  bool _loadingPrinters = true;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
    _loadCustomSizes();
  }

  Future<void> _loadPrinters() async {
    try {
      final printers = await PrinterRegistry.active.listPrinters();
      if (mounted) setState(() { _printers = printers; _loadingPrinters = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _loadCustomSizes() async {
    final sizes = await PaperSizeService.getAll();
    if (mounted) setState(() => _customSizes = sizes);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final template = state.template;
    if (template == null) return const SizedBox.shrink();

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        // Printer selector
        Icon(Icons.print_outlined, size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        _PrinterDropdown(
          printers: _printers,
          loading: _loadingPrinters,
          selectedId: template.printerId,
          selectedName: template.printerName,
          onChanged: (printer) => _savePrinter(context, state, template, printer),
        ),

        const SizedBox(width: 12),
        // Local fallback printer — used when the primary (e.g. a PrintNode
        // cloud printer) is offline. Only local/OS printers are offered here.
        Icon(Icons.print_disabled_outlined,
            size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        _PrinterDropdown(
          printers: _printers.where((p) => p.isLocal).toList(),
          loading: _loadingPrinters,
          selectedId: template.fallbackPrinterId,
          selectedName: template.fallbackPrinterName,
          emptyLabel: 'No fallback',
          onChanged: (printer) =>
              _saveFallbackPrinter(context, state, template, printer),
        ),

        const Spacer(),

        // Canvas / paper size selector
        Icon(Icons.article_outlined, size: 13, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        _PaperSizeDropdown(
          template: template,
          customSizes: _customSizes,
          onSizeSelected: (wMm, hMm) => _applySize(context, state, wMm, hMm),
          onAddCustom: () => _showAddCustomDialog(context, state),
        ),
      ]),
    );
  }

  Future<void> _savePrinter(
      BuildContext context,
      EditorState state,
      Template template,
      PapercraftPrinter? printer) async {
    final updated = template.copyWith(
      printerName: printer?.name,
      printerId: printer?.id,
      clearPrinter: printer == null,
    );
    final saved = await state.storage.save(updated);
    state.updateTemplate(saved);
    state.onSaved?.call(saved);
  }

  Future<void> _saveFallbackPrinter(
      BuildContext context,
      EditorState state,
      Template template,
      PapercraftPrinter? printer) async {
    final updated = template.copyWith(
      fallbackPrinterName: printer?.name,
      fallbackPrinterId: printer?.id,
      clearFallbackPrinter: printer == null,
    );
    final saved = await state.storage.save(updated);
    state.updateTemplate(saved);
    state.onSaved?.call(saved);
  }

  Future<void> _applySize(
      BuildContext context, EditorState state, double wMm, double hMm) async {
    final warnCount = state.previewCanvasResize(wMm, hMm);
    if (warnCount > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Resize canvas?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          content: Text(
            '$warnCount element${warnCount == 1 ? '' : 's'} will be '
            'partially or fully outside the new canvas size.\n\n'
            'The layout will be adjusted as best as possible.',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
              ),
              child: const Text('Resize anyway'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await state.applyCanvasResize(wMm, hMm);
  }

  Future<void> _showAddCustomDialog(BuildContext context, EditorState state) async {
    final wCtrl = TextEditingController();
    final hCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Add custom paper size',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. My Label'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: wCtrl,
                decoration: const InputDecoration(labelText: 'Width (mm)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: hCtrl,
                decoration: const InputDecoration(labelText: 'Height (mm)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () async {
              final w = double.tryParse(wCtrl.text);
              final h = double.tryParse(hCtrl.text);
              final name = nameCtrl.text.trim();
              if (w == null || h == null || w <= 0 || h <= 0) return;
              final key =
                  'custom_${name.toLowerCase().replaceAll(' ', '_')}_${w.round()}x${h.round()}';
              final size = CustomPaperSize(
                key: key,
                label: name.isEmpty ? '${w.round()}×${h.round()} mm' : name,
                widthMm: w,
                heightMm: h,
              );
              await PaperSizeService.save(size);
              if (mounted) setState(() => _customSizes = [..._customSizes, size]);
              Navigator.of(ctx).pop();
              // Apply immediately
              await _applySize(context, state, w, h);
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
    wCtrl.dispose();
    hCtrl.dispose();
    nameCtrl.dispose();
  }
}

// ── Printer dropdown ─────────────────────────────────────────────────────────

class _PrinterDropdown extends StatelessWidget {
  static const _noneValue = '__none__';

  final List<PapercraftPrinter> printers;
  final bool loading;
  final String? selectedId;
  final String? selectedName;
  final void Function(PapercraftPrinter?) onChanged;

  /// Label shown when nothing is selected (e.g. 'None (dialog on print)' for the
  /// primary printer, 'No fallback' for the fallback picker).
  final String emptyLabel;

  const _PrinterDropdown({
    required this.printers,
    required this.loading,
    required this.selectedId,
    required this.selectedName,
    required this.onChanged,
    this.emptyLabel = 'None (dialog on print)',
  });

  String get _currentLabel {
    if (selectedId == null && selectedName == null) {
      return emptyLabel;
    }
    final match = printers.where((p) =>
        (selectedId != null && p.id == selectedId) ||
        (selectedName != null && p.name == selectedName)).firstOrNull;
    if (match == null) return selectedName ?? selectedId!;
    return match.isLocal ? match.name : '${match.name} (external)';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Text('Loading…',
          style: TextStyle(fontSize: 11, color: AppColors.mutedForeground));
    }

    return GestureDetector(
      onTap: () => _showPrinterMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              _currentLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.foreground),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down,
              size: 16, color: AppColors.mutedForeground),
        ]),
      ),
    );
  }

  void _showPrinterMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: _noneValue,
        height: 32,
        child: Text(emptyLabel, style: const TextStyle(fontSize: 11)),
      ),
      ...printers.map((p) => PopupMenuItem<String>(
            value: p.id,
            height: 32,
            child: Text(
                p.isLocal ? p.name : '${p.name} (external)',
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis),
          )),
    ];

    final menuHeight = (items.length * 32.0).clamp(80, 320);

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - menuHeight,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: items,
      color: AppColors.card,
    );

    if (selected == null) return;
    if (selected == _noneValue) {
      onChanged(null);
      return;
    }
    onChanged(printers.where((p) => p.id == selected).firstOrNull);
  }
}

// ── Paper size dropdown ───────────────────────────────────────────────────────

class _PaperSizeDropdown extends StatelessWidget {
  final Template template;
  final List<CustomPaperSize> customSizes;
  final void Function(double wMm, double hMm) onSizeSelected;
  final VoidCallback onAddCustom;

  const _PaperSizeDropdown({
    required this.template,
    required this.customSizes,
    required this.onSizeSelected,
    required this.onAddCustom,
  });

  String get _currentLabel {
    // Match built-in
    for (final s in kCanvasSizes) {
      if ((s.widthMm - template.canvasWidthMm).abs() < 0.5 &&
          (s.heightMm - template.canvasHeightMm).abs() < 0.5) {
        return '${s.label} · ${_fmt(s.widthMm)}×${_fmt(s.heightMm)} mm';
      }
    }
    // Match custom
    for (final s in customSizes) {
      if ((s.widthMm - template.canvasWidthMm).abs() < 0.5 &&
          (s.heightMm - template.canvasHeightMm).abs() < 0.5) {
        return '${s.label} · ${_fmt(s.widthMm)}×${_fmt(s.heightMm)} mm';
      }
    }
    return '${_fmt(template.canvasWidthMm)}×${_fmt(template.canvasHeightMm)} mm';
  }

  String _fmt(double mm) =>
      mm == mm.roundToDouble() ? mm.round().toString() : mm.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSizeMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_currentLabel,
              style: const TextStyle(fontSize: 11, color: AppColors.foreground)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.mutedForeground),
        ]),
      ),
    );
  }

  void _showSizeMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final items = <PopupMenuEntry<String>>[];

    // Built-in sizes grouped
    items.add(const PopupMenuItem<String>(
      enabled: false,
      height: 28,
      child: PaperFieldLabel('Documents'),
    ));
    for (final s in kCanvasSizes.where((s) => s.category != 'label')) {
      items.add(PopupMenuItem<String>(
        value: '${s.widthMm}:${s.heightMm}',
        height: 32,
        child: Text('${s.label}  ${_fmt(s.widthMm)}×${_fmt(s.heightMm)} mm',
            style: const TextStyle(fontSize: 12)),
      ));
    }

    items.add(const PopupMenuDivider());
    items.add(const PopupMenuItem<String>(
      enabled: false,
      height: 28,
      child: PaperFieldLabel('Labels'),
    ));
    for (final s in kCanvasSizes.where((s) => s.category == 'label')) {
      items.add(PopupMenuItem<String>(
        value: '${s.widthMm}:${s.heightMm}',
        height: 32,
        child: Text('${s.label}  ${_fmt(s.widthMm)}×${_fmt(s.heightMm)} mm',
            style: const TextStyle(fontSize: 12)),
      ));
    }

    if (customSizes.isNotEmpty) {
      items.add(const PopupMenuDivider());
      items.add(const PopupMenuItem<String>(
        enabled: false,
        height: 28,
        child: PaperFieldLabel('Custom sizes'),
      ));
      for (final s in customSizes) {
        items.add(PopupMenuItem<String>(
          value: '${s.widthMm}:${s.heightMm}',
          height: 32,
          child: Text('${s.label}  ${_fmt(s.widthMm)}×${_fmt(s.heightMm)} mm',
              style: const TextStyle(fontSize: 12)),
        ));
      }
    }

    items.add(const PopupMenuDivider());
    items.add(const PopupMenuItem<String>(
      value: '__add_custom__',
      height: 32,
      child: Row(children: [
        Icon(Icons.add, size: 14, color: AppColors.accent),
        SizedBox(width: 6),
        Text('Add custom size…', style: TextStyle(fontSize: 12, color: AppColors.accent)),
      ]),
    ));

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - (items.length * 32.0).clamp(100, 400),
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: items,
      color: AppColors.card,
    );

    if (selected == null) return;
    if (selected == '__add_custom__') {
      onAddCustom();
      return;
    }
    final parts = selected.split(':');
    if (parts.length == 2) {
      final w = double.tryParse(parts[0]);
      final h = double.tryParse(parts[1]);
      if (w != null && h != null) onSizeSelected(w, h);
    }
  }
}
