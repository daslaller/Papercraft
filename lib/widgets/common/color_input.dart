import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ColorInput extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const ColorInput({super.key, required this.value, required this.onChanged});

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
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onSubmitted: (v) {
            if (v.startsWith('#') && v.length >= 4) onChanged(v);
          },
        ),
      ),
    ]);
  }

  void _openPicker(BuildContext context) async {
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
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
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
                  'FF${_ctrl.text.replaceAll('#', '')}', radix: 16));
              Navigator.of(context).pop(c);
            } catch (_) {}
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
