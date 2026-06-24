import 'package:flutter/material.dart';
import '../../models/element_model.dart';
import '../../models/template_model.dart';
import '../../services/token_service.dart';
import '../../theme/app_colors.dart';
import '../editor/element_renderer.dart';

class PreviewModal extends StatefulWidget {
  final Template template;
  final List<CanvasElement> elements;

  const PreviewModal({
    super.key,
    required this.template,
    required this.elements,
  });

  @override
  State<PreviewModal> createState() => _PreviewModalState();
}

class _PreviewModalState extends State<PreviewModal> {
  List<ComputedField> _computed = [];

  @override
  void initState() {
    super.initState();
    _loadComputed();
  }

  Future<void> _loadComputed() async {
    if (widget.template.connectedEntity != null) {
      final c = await TokenService.loadComputedFields(
          widget.template.connectedEntity!);
      if (mounted) setState(() => _computed = c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canvasW = mmToPx(widget.template.canvasWidthMm);
    final canvasH = mmToPx(widget.template.canvasHeightMm);
    final scale = [1.0, 560 / canvasW, 600 / canvasH]
        .reduce((a, b) => a < b ? a : b);

    Color bgColor;
    try {
      bgColor = Color(int.parse(
          'FF${widget.template.backgroundColor.replaceAll('#', '')}',
          radix: 16));
    } catch (_) {
      bgColor = Colors.white;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: 768,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.shadowXL,
          ),
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(children: [
                const Icon(Icons.visibility_outlined,
                    size: 16, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Preview',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 16),
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Canvas preview area
            Expanded(
              child: Container(
                color: AppColors.workspaceBg,
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: SizedBox(
                    width: canvasW * scale,
                    height: canvasH * scale,
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: canvasW,
                        height: canvasH,
                        color: bgColor,
                        child: Stack(children: [
                          if (widget.elements.any((e) => e.isSection))
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Column(
                                children: widget.elements
                                    .where((e) => e.isSection)
                                    .map((e) => ElementRenderer(
                                          el: e as ContainerElement,
                                          computedFields: _computed,
                                        ))
                                    .toList(),
                              ),
                            ),
                          ...() {
                            final els = widget.elements
                                .where((e) => !e.isSection && e.x != null)
                                .toList()
                              ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
                            return els.map((e) => Positioned(
                                  left: e.x!,
                                  top: e.y!,
                                  child: Transform.rotate(
                                    angle: e.rotation * 3.14159 / 180,
                                    alignment: Alignment.topLeft,
                                    child: ElementRenderer(
                                      el: e,
                                      computedFields: _computed,
                                    ),
                                  ),
                                )).toList();
                          }(),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
