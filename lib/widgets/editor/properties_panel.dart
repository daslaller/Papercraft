import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/element_model.dart';
import '../../models/gradient_def.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import '../common/gradient_editor.dart';
import '../common/paper_chrome.dart';

// ── Common small widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatefulWidget {
  final String title;
  final bool defaultOpen;
  final Widget child;

  const _SectionHeader({
    required this.title,
    this.defaultOpen = true,
    required this.child,
  });

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.defaultOpen;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.transparent,
          child: Row(children: [
            Expanded(child: PaperFieldLabel(widget.title)),
            Text(_open ? '›' : '›',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w300,
                    height: 1)),
          ]),
        ),
      ),
      if (_open)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: widget.child,
        ),
      const Divider(height: 1, color: AppColors.border),
    ]);
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10, color: AppColors.mutedForeground, height: 1.6));
}

class _NumInput extends StatefulWidget {
  final double value;
  final double? min;
  final double? max;
  final double step;
  final void Function(double) onChanged;

  const _NumInput({
    required this.value,
    this.min,
    this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  State<_NumInput> createState() => _NumInputState();
}

class _NumInputState extends State<_NumInput> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(_NumInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final formatted = _fmt(widget.value);
      if (_ctrl.text != formatted) _ctrl.text = formatted;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => (v * 10).round() / 10 == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.border)),
      ),
      onSubmitted: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) {
          final clamped = parsed.clamp(
              widget.min ?? double.negativeInfinity,
              widget.max ?? double.infinity);
          widget.onChanged(clamped);
        }
      },
    );
  }
}

class _ColorInput extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _ColorInput({required this.value, required this.onChanged});

  Color get _color {
    try {
      return Color(int.parse('FF${value.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _color,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: TextField(
          controller: TextEditingController(text: value.toUpperCase()),
          style: const TextStyle(
              fontSize: 11, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border)),
          ),
          onSubmitted: (v) {
            if (v.startsWith('#') && v.length >= 4) onChanged(v);
          },
        ),
      ),
    ]);
  }

  void _openPicker(BuildContext context) async {
    // Simple color picker using a dialog
    Color? picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(initial: _color),
    );
    if (picked != null) {
      final hex = '#${picked.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      onChanged(hex);
    }
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color initial;
  const _ColorPickerDialog({required this.initial});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final hex = widget.initial.toARGB32().toRadixString(16).substring(2).toUpperCase();
    _ctrl = TextEditingController(text: '#$hex');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Preset colors
        Wrap(spacing: 8, runSpacing: 8, children: [
          '#000000', '#FFFFFF', '#FF0000', '#00FF00', '#0000FF',
          '#FFFF00', '#FF00FF', '#00FFFF', '#FFA500', '#800080',
          '#6366F1', '#EC4899', '#F04E4E', '#1A1C23', '#E8E6E1',
        ].map((hex) {
          final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          decoration: const InputDecoration(labelText: 'Hex color (#RRGGBB)'),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            try {
              final c = Color(int.parse(
                  'FF${_ctrl.text.replaceAll('#', '')}',
                  radix: 16));
              Navigator.of(context).pop(c);
            } catch (_) {}
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ── Main Properties Panel ─────────────────────────────────────────────────────

class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final el = state.selectedElement;

    if (el == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Center(
                  child: Text('↖',
                      style: TextStyle(color: AppColors.mutedForeground))),
            ),
            const SizedBox(height: 12),
            const Text('Select an element\nto inspect',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                    height: 1.5)),
          ]),
        ),
      );
    }

    void update(CanvasElement updated) {
      state.commitUpdate(el.id, updated);
    }

    return ListView(children: [
      // Position & Size (for absolute elements)
      if (el.x != null) _buildPositionSection(el, update),

      // Flex child controls (when inside a row/col)
      if (el.x == null) _buildFlexChildSection(el, update),

      // Type-specific sections
      if (el is TextElement) _buildTextSection(el, update),
      if (el is ShapeElement) _buildShapeSection(el, update),
      if (el is ImageElement) _buildImageSection(el, update),
      if (el is QrElement) _buildQrSection(el, update),
      if (el is BarcodeElement) _buildBarcodeSection(el, update),
      if (el is ContainerElement) _buildLayoutSection(el, update),

      // Elevation (absolute only)
      if (el.x != null) _buildElevationSection(el, update),

      // Layer (absolute only)
      if (el.x != null) _buildLayerSection(el, state),

      const SizedBox(height: 20),
    ]);
  }

  Widget _buildPositionSection(
      CanvasElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'Position & Size',
      child: Column(children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('X'),
            _NumInput(
              value: el.x ?? 0,
              onChanged: (v) => update(_withX(el, v)),
            ),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Y'),
            _NumInput(
              value: el.y ?? 0,
              onChanged: (v) => update(_withY(el, v)),
            ),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('W'),
            _NumInput(
              value: el.width ?? 100,
              min: 10,
              onChanged: (v) => update(_withW(el, v)),
            ),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('H'),
            _NumInput(
              value: el.height ?? 100,
              min: 10,
              onChanged: (v) => update(_withH(el, v)),
            ),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Rotation'),
            _NumInput(
              value: el.rotation,
              min: -180,
              max: 180,
              onChanged: (v) => update(_withRot(el, v)),
            ),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Opacity %'),
            _NumInput(
              value: el.opacity * 100,
              min: 0,
              max: 100,
              onChanged: (v) => update(_withOp(el, v / 100)),
            ),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildTextSection(
      TextElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'Text',
      child: Column(children: [
        // Font family
        const _Label('Font'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: el.fontFamily,
          isDense: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border)),
          ),
          items: const [
            'Inter', 'Playfair Display', 'Lora', 'DM Mono',
            'Georgia', 'Arial', 'Helvetica', 'Times New Roman', 'Courier New'
          ].map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontFamily: f, fontSize: 12)))).toList(),
          onChanged: (v) { if (v != null) update(el.copyWith(fontFamily: v)); },
        ),
        const SizedBox(height: 8),
        // Size + Leading
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Size'),
            _NumInput(value: el.fontSize, min: 6, max: 200,
                onChanged: (v) => update(el.copyWith(fontSize: v))),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Leading'),
            _NumInput(value: el.lineHeight, min: 0.8, max: 4, step: 0.1,
                onChanged: (v) => update(el.copyWith(lineHeight: v))),
          ])),
        ]),
        const SizedBox(height: 8),
        // Tracking (letter-spacing)
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Tracking'),
            _NumInput(
              value: el.letterSpacing ?? 0,
              min: -10,
              max: 50,
              step: 0.5,
              onChanged: (v) => update(v == 0
                  ? el.copyWith(clearLetterSpacing: true)
                  : el.copyWith(letterSpacing: v)),
            ),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Underline'),
            const SizedBox(height: 4),
            _ToggleButton(
              on: el.textDecoration == 'underline',
              onTap: () => update(el.textDecoration == 'underline'
                  ? el.copyWith(clearDecoration: true)
                  : el.copyWith(textDecoration: 'underline')),
            ),
          ])),
        ]),
        const SizedBox(height: 8),
        // Weight + Style
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Weight'),
            DropdownButtonFormField<String>(
              value: el.fontWeight,
              isDense: true,
              decoration: _dropDeco(),
              items: const [
                DropdownMenuItem(value: '300', child: Text('Light', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'normal', child: Text('Regular', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: '500', child: Text('Medium', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: '600', child: Text('Semibold', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'bold', child: Text('Bold', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: '800', child: Text('ExtraBold', style: TextStyle(fontSize: 11))),
              ],
              onChanged: (v) { if (v != null) update(el.copyWith(fontWeight: v)); },
            ),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Style'),
            DropdownButtonFormField<String>(
              value: el.fontStyle,
              isDense: true,
              decoration: _dropDeco(),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'italic', child: Text('Italic', style: TextStyle(fontSize: 11))),
              ],
              onChanged: (v) { if (v != null) update(el.copyWith(fontStyle: v)); },
            ),
          ])),
        ]),
        const SizedBox(height: 8),
        // Text align
        const _Label('Align'),
        const SizedBox(height: 4),
        Row(children: [
          for (final align in ['left', 'center', 'right', 'justify']) ...[
            Expanded(child: _AlignButton(
              icon: switch (align) {
                'center' => Icons.format_align_center,
                'right' => Icons.format_align_right,
                'justify' => Icons.format_align_justify,
                _ => Icons.format_align_left,
              },
              active: el.textAlign == align,
              onTap: () => update(el.copyWith(textAlign: align)),
            )),
            if (align != 'justify') const SizedBox(width: 4),
          ],
        ]),
        const SizedBox(height: 8),
        // Color
        const _Label('Color'),
        const SizedBox(height: 4),
        _ColorInput(
          value: el.color,
          onChanged: (v) => update(el.copyWith(color: v)),
        ),
        const SizedBox(height: 12),
        // Gradient
        GradientEditor(
          gradient: el.textGradient,
          onChanged: (g) => update(el.copyWith(textGradient: g, clearGradient: g == null)),
        ),
        // AlignSelf (shown for flex children)
        if (el.x == null && el.y == null) ...[
          const SizedBox(height: 12),
          const _Label('Align self'),
          const SizedBox(height: 4),
          _AlignSelfDropdown(
            value: el.alignSelf ?? 'auto',
            onChanged: (v) => update(el.copyWith(alignSelf: v)),
          ),
        ],
      ]),
    );
  }

  Widget _buildShapeSection(
      ShapeElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'Shape',
      child: Column(children: [
        const _Label('Fill'),
        const SizedBox(height: 4),
        _ColorInput(value: el.fill, onChanged: (v) => update(el.copyWith(fill: v))),
        const SizedBox(height: 8),
        const _Label('Stroke'),
        const SizedBox(height: 4),
        _ColorInput(value: el.stroke, onChanged: (v) => update(el.copyWith(stroke: v))),
        const SizedBox(height: 8),
        const _Label('Stroke W'),
        const SizedBox(height: 4),
        _NumInput(value: el.strokeWidth, min: 0, max: 20,
            onChanged: (v) => update(el.copyWith(strokeWidth: v))),
        const SizedBox(height: 12),
        _CornerRadiusEditor(
          corners: el.corners,
          onUniform: (v) => update(el.copyWith(
            borderRadius: v,
            clearCornerRadii: true,
          )),
          onUnlink: () {
            final u = el.corners.asUnlinked();
            update(el.copyWith(
              borderRadius: u.borderRadius,
              borderRadiusTL: u.borderRadiusTL,
              borderRadiusTR: u.borderRadiusTR,
              borderRadiusBR: u.borderRadiusBR,
              borderRadiusBL: u.borderRadiusBL,
            ));
          },
          onCorner: (tl, tr, br, bl) => update(el.copyWith(
            borderRadiusTL: tl,
            borderRadiusTR: tr,
            borderRadiusBR: br,
            borderRadiusBL: bl,
          )),
        ),
        const SizedBox(height: 12),
        GradientEditor(
          gradient: el.gradient,
          onChanged: (g) => update(el.copyWith(gradient: g, clearGradient: g == null)),
        ),
        if (el.x == null && el.y == null) ...[
          const SizedBox(height: 12),
          const _Label('Align self'),
          const SizedBox(height: 4),
          _AlignSelfDropdown(
            value: el.alignSelf ?? 'auto',
            onChanged: (v) => update(el.copyWith(alignSelf: v)),
          ),
        ],
      ]),
    );
  }

  Widget _buildImageSection(
      ImageElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'Image',
      child: Column(children: [
        const _Label('URL'),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: el.src),
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            hintText: 'https://…',
            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          ),
          onSubmitted: (v) => update(el.copyWith(src: v)),
        ),
        const SizedBox(height: 8),
        const _Label('Fit'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: el.objectFit,
          isDense: true,
          decoration: _dropDeco(),
          items: const ['cover', 'contain', 'fill', 'none']
              .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 11))))
              .toList(),
          onChanged: (v) { if (v != null) update(el.copyWith(objectFit: v)); },
        ),
        const SizedBox(height: 8),
        _CornerRadiusEditor(
          corners: el.corners,
          onUniform: (v) => update(el.copyWith(
            borderRadius: v,
            clearCornerRadii: true,
          )),
          onUnlink: () {
            final u = el.corners.asUnlinked();
            update(el.copyWith(
              borderRadius: u.borderRadius,
              borderRadiusTL: u.borderRadiusTL,
              borderRadiusTR: u.borderRadiusTR,
              borderRadiusBR: u.borderRadiusBR,
              borderRadiusBL: u.borderRadiusBL,
            ));
          },
          onCorner: (tl, tr, br, bl) => update(el.copyWith(
            borderRadiusTL: tl,
            borderRadiusTR: tr,
            borderRadiusBR: br,
            borderRadiusBL: bl,
          )),
        ),
      ]),
    );
  }

  Widget _buildQrSection(QrElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'QR Code',
      child: Column(children: [
        const _Label('Content / URL'),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: el.content),
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            hintText: 'https://…',
            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          ),
          onSubmitted: (v) => update(el.copyWith(content: v)),
        ),
      ]),
    );
  }

  Widget _buildBarcodeSection(
      BarcodeElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'Barcode',
      child: Column(children: [
        const _Label('Value / Field'),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: el.content),
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            hintText: '1234567890 or {{field}}',
            border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          ),
          onSubmitted: (v) => update(el.copyWith(content: v)),
        ),
        const SizedBox(height: 8),
        const _Label('Format'),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: el.format,
          isDense: true,
          decoration: _dropDeco(),
          items: const ['CODE128', 'CODE39', 'EAN13', 'EAN8', 'UPC', 'ITF14', 'MSI', 'pharmacode']
              .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 11))))
              .toList(),
          onChanged: (v) { if (v != null) update(el.copyWith(format: v)); },
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Color'),
            _ColorInput(value: el.color, onChanged: (v) => update(el.copyWith(color: v))),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('BG'),
            _ColorInput(value: el.background, onChanged: (v) => update(el.copyWith(background: v))),
          ])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Show text', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          const Spacer(),
          _ToggleButton(
            on: el.displayValue,
            onTap: () => update(el.copyWith(displayValue: !el.displayValue)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildFlexChildSection(
      CanvasElement el, void Function(CanvasElement) update) {
    final flex = switch (el) {
      TextElement e => e.flex ?? 1,
      ShapeElement e => e.flex ?? 1,
      ImageElement e => e.flex ?? 1,
      QrElement e => e.flex ?? 1,
      BarcodeElement e => e.flex ?? 1,
      ContainerElement e => e.flex ?? 1,
      _ => 1,
    };

    void setFlex(int v) {
      final clamped = v.clamp(1, 12);
      update(switch (el) {
        TextElement e => e.copyWith(flex: clamped),
        ShapeElement e => e.copyWith(flex: clamped),
        ImageElement e => e.copyWith(flex: clamped),
        QrElement e => e.copyWith(flex: clamped),
        BarcodeElement e => e.copyWith(flex: clamped),
        ContainerElement e => e.copyWith(flex: clamped),
        _ => el,
      });
    }

    void setHeight(double? v) {
      update(switch (el) {
        TextElement e => e.copyWith(height: v),
        ShapeElement e => e.copyWith(height: v),
        ImageElement e => e.copyWith(height: v),
        QrElement e => e.copyWith(height: v),
        BarcodeElement e => e.copyWith(height: v),
        ContainerElement e => e.copyWith(height: v),
        _ => el,
      });
    }

    return _SectionHeader(
      title: 'Flex child',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Label('Flex weight  (higher = wider share in Row)'),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(trackHeight: 2),
              child: Slider(
                value: flex.toDouble().clamp(1, 12),
                min: 1,
                max: 12,
                divisions: 11,
                label: '$flex',
                onChanged: (v) => setFlex(v.round()),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('$flex',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 8),
        const _Label('Height (leave blank = auto)'),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: _NumInput(
              value: el.height ?? 0,
              min: 0,
              max: 2000,
              onChanged: (v) => setHeight(v <= 0 ? null : v),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => setHeight(null),
            child: const Text('Auto', style: TextStyle(fontSize: 11)),
          ),
        ]),
      ]),
    );
  }

  Widget _buildLayoutSection(
      ContainerElement el, void Function(CanvasElement) update) {
    return _SectionHeader(
      title: 'Layout',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Axis selector: Row | Column
        const _Label('Axis'),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(2),
          child: Row(children: [
            _ModeBtn(label: '↔ Row',    value: 'row', current: el.type, onTap: (m) => update(el.copyWith(type: m))),
            _ModeBtn(label: '↕ Column', value: 'col', current: el.type, onTap: (m) => update(el.copyWith(type: m))),
          ]),
        ),
        const SizedBox(height: 12),
        // Section toggle — individual override; global setting is the new-element default
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Label('Section layout'),
            Text(
              'Flows with document instead of free position',
              style: TextStyle(fontSize: 9, color: AppColors.mutedForeground, height: 1.4),
            ),
          ])),
          const SizedBox(width: 8),
          _ToggleButton(
            on: el.isSection,
            onTap: () {
              if (el.isSection) {
                // Switching to absolute: give it a position if it doesn't have one
                update(el.copyWith(
                  isSection: false,
                  x: el.x ?? 20,
                  y: el.y ?? 20,
                  width: el.width ?? 200,
                  height: el.height ?? 80,
                ));
              } else {
                update(el.copyWith(isSection: true));
              }
            },
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Gap'),
            _NumInput(value: el.gap, min: 0, max: 100,
                onChanged: (v) => update(el.copyWith(gap: v))),
          ])),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Padding'),
            _NumInput(value: el.padding, min: 0, max: 80,
                onChanged: (v) => update(el.copyWith(padding: v))),
          ])),
        ]),
        const SizedBox(height: 12),
        const _Label('Background'),
        const SizedBox(height: 4),
        _ColorInput(
          value: el.background == 'transparent' ? '#ffffff' : el.background,
          onChanged: (v) => update(el.copyWith(background: v)),
        ),
        const SizedBox(height: 8),
        _CornerRadiusEditor(
          corners: el.corners,
          onUniform: (v) => update(el.copyWith(
            borderRadius: v,
            clearCornerRadii: true,
          )),
          onUnlink: () {
            final u = el.corners.asUnlinked();
            update(el.copyWith(
              borderRadius: u.borderRadius,
              borderRadiusTL: u.borderRadiusTL,
              borderRadiusTR: u.borderRadiusTR,
              borderRadiusBR: u.borderRadiusBR,
              borderRadiusBL: u.borderRadiusBL,
            ));
          },
          onCorner: (tl, tr, br, bl) => update(el.copyWith(
            borderRadiusTL: tl,
            borderRadiusTR: tr,
            borderRadiusBR: br,
            borderRadiusBL: bl,
          )),
        ),
      ]),
    );
  }

  // ── Elevation ────────────────────────────────────────────────────────────────

  Widget _buildElevationSection(
      CanvasElement el, void Function(CanvasElement) update) {
    final shadows = ['None', 'Sm', 'Md', 'Lg', 'XL'];
    final shadowVals = {
      'None': null,
      'Sm': '0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08)',
      'Md': '0 4px 12px rgba(0,0,0,0.12), 0 2px 4px rgba(0,0,0,0.08)',
      'Lg': '0 8px 24px rgba(0,0,0,0.14), 0 4px 8px rgba(0,0,0,0.08)',
      'XL': '0 16px 48px rgba(0,0,0,0.18), 0 6px 12px rgba(0,0,0,0.10)',
    };

    final current = el is TextElement ? el.boxShadow :
                    el is ShapeElement ? el.boxShadow :
                    el is ContainerElement ? el.boxShadow : null;

    return _SectionHeader(
      title: 'Elevation',
      defaultOpen: false,
      child: Wrap(spacing: 4, runSpacing: 4, children: shadows.map((s) {
        final active = current == shadowVals[s];
        return GestureDetector(
          onTap: () {
            final val = shadowVals[s];
            if (el is TextElement) update(el.copyWith(boxShadow: val, clearShadow: val == null));
            if (el is ShapeElement) update(el.copyWith(boxShadow: val, clearShadow: val == null));
            if (el is ContainerElement) update(el.copyWith(boxShadow: val, clearShadow: val == null));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.accent : Colors.transparent,
              border: Border.all(
                color: active ? AppColors.accent : AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s, style: TextStyle(
                fontSize: 10,
                color: active ? AppColors.accentForeground : AppColors.mutedForeground)),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildLayerSection(CanvasElement el, EditorState state) {
    return _SectionHeader(
      title: 'Layer',
      defaultOpen: false,
      child: Column(children: [
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => state.bringForward(el.id),
            icon: const Icon(Icons.keyboard_arrow_up, size: 11),
            label: const Text('Forward', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => state.sendBack(el.id),
            icon: const Icon(Icons.keyboard_arrow_down, size: 11),
            label: const Text('Back', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          )),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => state.deleteElement(el.id),
            icon: const Icon(Icons.delete_outline, size: 11, color: AppColors.destructive),
            label: const Text('Delete element',
                style: TextStyle(fontSize: 11, color: AppColors.destructive)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.destructive, width: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ]),
    );
  }
}

InputDecoration _dropDeco() => InputDecoration(
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.border)),
);

class _AlignButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _AlignButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.foreground : Colors.transparent,
        border: Border.all(
            color: active ? AppColors.foreground : AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon,
          size: 12,
          color: active ? AppColors.background : AppColors.mutedForeground),
    ),
  );
}

class _AlignSelfDropdown extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _AlignSelfDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    isDense: true,
    decoration: _dropDeco(),
    items: const [
      DropdownMenuItem(value: 'auto', child: Text('Auto (default)', style: TextStyle(fontSize: 11))),
      DropdownMenuItem(value: 'flex-start', child: Text('Start', style: TextStyle(fontSize: 11))),
      DropdownMenuItem(value: 'center', child: Text('Center', style: TextStyle(fontSize: 11))),
      DropdownMenuItem(value: 'flex-end', child: Text('End', style: TextStyle(fontSize: 11))),
      DropdownMenuItem(value: 'stretch', child: Text('Stretch', style: TextStyle(fontSize: 11))),
    ],
    onChanged: (v) { if (v != null) onChanged(v); },
  );
}

class _ToggleButton extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;

  const _ToggleButton({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: on ? AppColors.foreground : Colors.transparent,
        border: Border.all(color: on ? AppColors.foreground : AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(on ? 'On' : 'Off',
          style: TextStyle(
              fontSize: 11,
              color: on ? AppColors.background : AppColors.mutedForeground)),
    ),
  );
}

// ── Element update helpers ────────────────────────────────────────────────────

CanvasElement _withX(CanvasElement el, double v) {
  if (el is TextElement) return el.copyWith(x: v);
  if (el is ShapeElement) return el.copyWith(x: v);
  if (el is ImageElement) return el.copyWith(x: v);
  if (el is QrElement) return el.copyWith(x: v);
  if (el is BarcodeElement) return el.copyWith(x: v);
  if (el is ContainerElement) return el.copyWith(x: v);
  return el;
}

CanvasElement _withY(CanvasElement el, double v) {
  if (el is TextElement) return el.copyWith(y: v);
  if (el is ShapeElement) return el.copyWith(y: v);
  if (el is ImageElement) return el.copyWith(y: v);
  if (el is QrElement) return el.copyWith(y: v);
  if (el is BarcodeElement) return el.copyWith(y: v);
  if (el is ContainerElement) return el.copyWith(y: v);
  return el;
}

CanvasElement _withW(CanvasElement el, double v) {
  if (el is TextElement) return el.copyWith(width: v);
  if (el is ShapeElement) return el.copyWith(width: v);
  if (el is ImageElement) return el.copyWith(width: v);
  if (el is QrElement) return el.copyWith(width: v);
  if (el is BarcodeElement) return el.copyWith(width: v);
  if (el is ContainerElement) return el.copyWith(width: v);
  return el;
}

CanvasElement _withH(CanvasElement el, double v) {
  if (el is TextElement) return el.copyWith(height: v);
  if (el is ShapeElement) return el.copyWith(height: v);
  if (el is ImageElement) return el.copyWith(height: v);
  if (el is QrElement) return el.copyWith(height: v);
  if (el is BarcodeElement) return el.copyWith(height: v);
  if (el is ContainerElement) return el.copyWith(height: v);
  return el;
}

CanvasElement _withRot(CanvasElement el, double v) {
  if (el is TextElement) return el.copyWith(rotation: v);
  if (el is ShapeElement) return el.copyWith(rotation: v);
  if (el is ImageElement) return el.copyWith(rotation: v);
  if (el is QrElement) return el.copyWith(rotation: v);
  if (el is BarcodeElement) return el.copyWith(rotation: v);
  if (el is ContainerElement) return el.copyWith(rotation: v);
  return el;
}

CanvasElement _withOp(CanvasElement el, double v) {
  if (el is TextElement) return el.copyWith(opacity: v);
  if (el is ShapeElement) return el.copyWith(opacity: v);
  if (el is ImageElement) return el.copyWith(opacity: v);
  if (el is QrElement) return el.copyWith(opacity: v);
  if (el is BarcodeElement) return el.copyWith(opacity: v);
  if (el is ContainerElement) return el.copyWith(opacity: v);
  return el;
}

// ── Axis mode button ─────────────────────────────────────────────────────────

class _ModeBtn extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;

  const _ModeBtn({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.card : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: active ? AppColors.shadowSm : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? AppColors.foreground : AppColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Uniform or per-corner border radius editor for shape / image / row / col.
class _CornerRadiusEditor extends StatelessWidget {
  final CornerRadii corners;
  final void Function(double uniform) onUniform;
  final VoidCallback onUnlink;
  final void Function(double tl, double tr, double br, double bl) onCorner;

  const _CornerRadiusEditor({
    required this.corners,
    required this.onUniform,
    required this.onUnlink,
    required this.onCorner,
  });

  @override
  Widget build(BuildContext context) {
    final uniform = corners.isUniform;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: _Label('Corner radius')),
          GestureDetector(
            onTap: () {
              if (uniform) {
                onUnlink();
              } else {
                onUniform(corners.borderRadius);
              }
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                uniform ? Icons.link : Icons.link_off,
                size: 14,
                color: uniform ? AppColors.accent : AppColors.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(
                uniform ? 'Uniform' : 'Per corner',
                style: TextStyle(
                  fontSize: 10,
                  color: uniform ? AppColors.accent : AppColors.mutedForeground,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 4),
        if (uniform)
          _NumInput(
            value: corners.borderRadius,
            min: 0,
            max: 200,
            onChanged: onUniform,
          )
        else ...[
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('TL'),
                  _NumInput(
                    value: corners.topLeft,
                    min: 0,
                    max: 200,
                    onChanged: (v) => onCorner(
                      v, corners.topRight, corners.bottomRight, corners.bottomLeft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('TR'),
                  _NumInput(
                    value: corners.topRight,
                    min: 0,
                    max: 200,
                    onChanged: (v) => onCorner(
                      corners.topLeft, v, corners.bottomRight, corners.bottomLeft),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('BL'),
                  _NumInput(
                    value: corners.bottomLeft,
                    min: 0,
                    max: 200,
                    onChanged: (v) => onCorner(
                      corners.topLeft, corners.topRight, corners.bottomRight, v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('BR'),
                  _NumInput(
                    value: corners.bottomRight,
                    min: 0,
                    max: 200,
                    onChanged: (v) => onCorner(
                      corners.topLeft, corners.topRight, v, corners.bottomLeft),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ],
    );
  }
}
