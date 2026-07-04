import 'package:flutter/material.dart';
import '../models/element_model.dart';
import '../models/template_model.dart';
import '../services/token_service.dart';
import '../widgets/editor/element_renderer.dart';

/// Read-only canvas renderer — no editor chrome, no handles, no toolbar.
///
/// Use this to embed a filled template anywhere: list thumbnails, dashboards,
/// confirmation screens, etc.
///
/// ```dart
/// // Thumbnail in a list tile:
/// PapercraftRenderer(
///   template: template,
///   elements: template.elements,
///   record: {
///     'customer.name': 'Jane Doe',
///     'order.number':  'WO-4821',
///   },
///   scale: 0.3,
/// )
///
/// // Full-size preview that fills available space:
/// PapercraftRenderer.fitted(
///   template: template,
///   elements: template.elements,
///   record: record,
/// )
/// ```
class PapercraftRenderer extends StatelessWidget {
  final Template template;
  final List<CanvasElement> elements;

  /// Flat field map whose keys match `{{namespace.field}}` tokens.
  /// e.g. `{'customer.name': 'Jane', 'order.number': 'WO-99'}`.
  final Map<String, dynamic>? record;

  /// Entity name used for token resolution context (e.g. `'orders'`).
  final String? entityName;

  /// Optional pre-resolved computed fields.
  final List<ComputedField> computedFields;

  /// Explicit scale factor (1.0 = 1 px per canvas px, which is large).
  /// Use [PapercraftRenderer.fitted] to auto-fit into available space.
  final double scale;

  const PapercraftRenderer({
    super.key,
    required this.template,
    required this.elements,
    this.record,
    this.entityName,
    this.computedFields = const [],
    this.scale = 1.0,
  });

  /// Automatically fits the canvas to the available space.
  /// Preserves aspect ratio; never exceeds 1:1 scale.
  static Widget fitted({
    Key? key,
    required Template template,
    required List<CanvasElement> elements,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields = const [],
    double maxScale = 1.0,
  }) {
    return LayoutBuilder(
      key: key,
      builder: (_, constraints) {
        final cw = mmToPx(template.canvasWidthMm);
        final ch = mmToPx(template.canvasHeightMm);
        final scale = [
          maxScale,
          constraints.maxWidth / cw,
          constraints.maxHeight / ch,
        ].reduce((a, b) => a < b ? a : b);

        return PapercraftRenderer(
          template: template,
          elements: elements,
          record: record,
          entityName: entityName,
          computedFields: computedFields,
          scale: scale,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cw = mmToPx(template.canvasWidthMm);
    final ch = mmToPx(template.canvasHeightMm);

    Color bgColor;
    try {
      bgColor = Color(int.parse(
          'FF${template.backgroundColor.replaceAll('#', '')}',
          radix: 16));
    } catch (_) {
      bgColor = Colors.white;
    }

    final sections = elements.where((e) => e.isSection).toList();
    final absolute = elements
        .where((e) => !e.isSection && e.x != null)
        .toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return SizedBox(
      width: cw * scale,
      height: ch * scale,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: cw,
          height: ch,
          child: ClipRect(
            child: ColoredBox(
              color: bgColor,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (sections.isNotEmpty)
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: sections
                            .map((e) => ElementRenderer(
                                  el: e as ContainerElement,
                                  record: record,
                                  entityName: entityName,
                                  computedFields: computedFields,
                                  showTokenChips: false,
                                ))
                            .toList(),
                      ),
                    ),
                  ...absolute.map((e) => Positioned(
                        left: e.x!,
                        top: e.y!,
                        child: Transform.rotate(
                          angle: e.rotation * 3.14159265358979 / 180,
                          alignment: Alignment.topLeft,
                          child: ElementRenderer(
                            el: e,
                            record: record,
                            entityName: entityName,
                            computedFields: computedFields,
                            showTokenChips: false,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
