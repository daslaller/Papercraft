import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/element_model.dart';
import '../../models/template_model.dart';
import '../../services/print_service.dart';
import '../../services/printer_provider.dart';
import '../../services/token_service.dart';
import '../../theme/app_colors.dart';

class PrintPreviewModal extends StatefulWidget {
  final Template template;
  final List<CanvasElement> elements;
  final Map<String, dynamic>? record;
  final String? entityName;
  final List<ComputedField> computedFields;
  final void Function(PapercraftPrinter?)? onPrinterSelected;
  final void Function(Template template)? onPrinted;

  const PrintPreviewModal({
    super.key,
    required this.template,
    required this.elements,
    this.record,
    this.entityName,
    this.computedFields = const [],
    this.onPrinterSelected,
    this.onPrinted,
  });

  @override
  State<PrintPreviewModal> createState() => _PrintPreviewModalState();
}

class _PrintPreviewModalState extends State<PrintPreviewModal> {
  List<PapercraftPrinter> _printers = [];
  PapercraftPrinter? _selectedPrinter;
  bool _loadingPrinters = true;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    try {
      final printers = await PrinterRegistry.active.listPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          _loadingPrinters = false;
          _selectedPrinter = PrinterProvider.resolveFromList(
            widget.template,
            printers,
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 800),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              const Icon(Icons.print_outlined, size: 18, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Print — ${widget.template.name}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              if (!_loadingPrinters && _printers.isNotEmpty) ...[
                const Text('Printer: ',
                    style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                DropdownButton<PapercraftPrinter?>(
                  value: _selectedPrinter,
                  hint: const Text('Default', style: TextStyle(fontSize: 12)),
                  isDense: true,
                  underline: const SizedBox(),
                  style: const TextStyle(fontSize: 12, color: AppColors.foreground),
                  items: [
                    const DropdownMenuItem<PapercraftPrinter?>(
                      value: null,
                      child: Text('Default printer'),
                    ),
                    ..._printers.map((p) => DropdownMenuItem<PapercraftPrinter?>(
                          value: p,
                          child: Text(
                            p.isLocal ? p.name : '${p.name} (external)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (p) {
                    setState(() => _selectedPrinter = p);
                    widget.onPrinterSelected?.call(p);
                  },
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          Expanded(
            child: PdfPreview(
              build: (_) => PrintService.buildPdf(
                template: widget.template,
                elements: widget.elements,
                record: widget.record,
                entityName: widget.entityName,
                computedFields: widget.computedFields,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              allowSharing: true,
              loadingWidget: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Rendering PDF…', style: TextStyle(color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              actions: [
                PdfPreviewAction(
                  icon: const Icon(Icons.print, size: 18),
                  onPressed: (ctx, build, pageFormat) async {
                    final bytes = await build(pageFormat);
                    if (_selectedPrinter != null) {
                      await PrinterRegistry.active.printPdf(
                        _selectedPrinter!,
                        bytes,
                        jobName: widget.template.name,
                      );
                    } else {
                      await Printing.layoutPdf(
                        name: widget.template.name,
                        onLayout: (_) async => bytes,
                      );
                    }
                    widget.onPrinted?.call(widget.template);
                  },
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
