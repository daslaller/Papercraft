import 'package:flutter/material.dart';
import '../../models/gradient_def.dart';
import '../../theme/app_colors.dart';
import 'color_input.dart';

class GradientEditor extends StatefulWidget {
  final GradientDef? gradient;
  final void Function(GradientDef?) onChanged;

  const GradientEditor({super.key, required this.gradient, required this.onChanged});

  @override
  State<GradientEditor> createState() => _GradientEditorState();
}

class _GradientEditorState extends State<GradientEditor> {
  int _selectedStop = 0;

  GradientDef get _g =>
      widget.gradient ?? GradientDef.defaultGradient;

  @override
  Widget build(BuildContext context) {
    final g = _g;
    final isOn = widget.gradient != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Enable/disable row
      Row(children: [
        const Expanded(child: Text('Gradient', style: TextStyle(fontSize: 11))),
        Switch(
          value: isOn,
          onChanged: (v) {
            widget.onChanged(v ? GradientDef.defaultGradient : null);
            setState(() => _selectedStop = 0);
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),

      if (isOn) ...[
        const SizedBox(height: 6),

        // Type toggle
        Row(children: [
          _TypeBtn('Linear', g.type == 'linear',
              () => widget.onChanged(g.copyWith(type: 'linear'))),
          const SizedBox(width: 4),
          _TypeBtn('Radial', g.type == 'radial',
              () => widget.onChanged(g.copyWith(type: 'radial'))),
        ]),
        const SizedBox(height: 8),

        // Gradient preview bar with stop handles
        _GradientBar(
          gradient: g,
          selectedStop: _selectedStop,
          onSelectStop: (i) => setState(() => _selectedStop = i),
          onMoveStop: (i, pos) {
            final stops = [...g.stops];
            stops[i] = GradientStop(color: stops[i].color, pos: pos.clamp(0, 100));
            widget.onChanged(g.copyWith(stops: stops));
          },
          onAddStop: (pos) {
            final stops = [...g.stops, GradientStop(color: '#888888', pos: pos)];
            stops.sort((a, b) => a.pos.compareTo(b.pos));
            widget.onChanged(g.copyWith(stops: stops));
            setState(() => _selectedStop = stops.indexWhere((s) => s.pos == pos));
          },
        ),
        const SizedBox(height: 8),

        // Selected stop editor
        if (g.stops.isNotEmpty && _selectedStop < g.stops.length) ...[
          Row(children: [
            const Text('Stop color', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            const Spacer(),
            if (g.stops.length > 2)
              GestureDetector(
                onTap: () {
                  final stops = [...g.stops]..removeAt(_selectedStop);
                  widget.onChanged(g.copyWith(stops: stops));
                  setState(() => _selectedStop = (_selectedStop - 1).clamp(0, stops.length - 1));
                },
                child: const Text('Remove stop',
                    style: TextStyle(fontSize: 10, color: AppColors.accent)),
              ),
          ]),
          const SizedBox(height: 4),
          ColorInput(
            value: g.stops[_selectedStop].color,
            onChanged: (hex) {
              final stops = [...g.stops];
              stops[_selectedStop] = GradientStop(color: hex, pos: stops[_selectedStop].pos);
              widget.onChanged(g.copyWith(stops: stops));
            },
          ),
        ],

        // Angle slider (linear only)
        if (g.type == 'linear') ...[
          const SizedBox(height: 8),
          Row(children: [
            const Text('Angle', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            const Spacer(),
            Text('${g.angle.round()}°',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ]),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppColors.accent,
              thumbColor: AppColors.accent,
              overlayColor: AppColors.accent.withOpacity(0.15),
              inactiveTrackColor: AppColors.border,
            ),
            child: Slider(
              value: g.angle,
              min: 0,
              max: 360,
              onChanged: (v) => widget.onChanged(g.copyWith(angle: v)),
            ),
          ),
        ],
      ],
    ]);
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TypeBtn(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          border: Border.all(color: active ? AppColors.accent : AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? AppColors.accentForeground : AppColors.foreground,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _GradientBar extends StatelessWidget {
  final GradientDef gradient;
  final int selectedStop;
  final void Function(int) onSelectStop;
  final void Function(int, double) onMoveStop;
  final void Function(double) onAddStop;

  const _GradientBar({
    required this.gradient,
    required this.selectedStop,
    required this.onSelectStop,
    required this.onMoveStop,
    required this.onAddStop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return SizedBox(
        height: 28,
        child: Stack(clipBehavior: Clip.none, children: [
          // Bar
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (d) {
                final frac = (d.localPosition.dx / w * 100).clamp(0.0, 100.0);
                onAddStop(frac);
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient.toFlutter(),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ),
          // Stop handles
          ...gradient.stops.asMap().entries.map((entry) {
            final i = entry.key;
            final stop = entry.value;
            final left = stop.pos / 100 * w - 7;
            return Positioned(
              left: left.clamp(-7.0, w - 7.0),
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => onSelectStop(i),
                onHorizontalDragUpdate: (d) {
                  final newPos = ((left + 7 + d.delta.dx) / w * 100).clamp(0.0, 100.0);
                  onMoveStop(i, newPos);
                },
                child: Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: stop.flutterColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == selectedStop ? Colors.white : AppColors.border,
                      width: i == selectedStop ? 2.5 : 1.5,
                    ),
                    boxShadow: AppColors.shadowSm,
                  ),
                ),
              ),
            );
          }),
        ]),
      );
    });
  }
}
