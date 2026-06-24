import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';

class ViewportNav extends StatelessWidget {
  final VoidCallback onPrint;

  const ViewportNav({super.key, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF7FFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x14000000)),
            boxShadow: AppColors.shadowLg,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // Pan/Select toggle
            _NavButton(
              icon: state.panMode ? Icons.mouse : Icons.pan_tool_outlined,
              active: state.panMode,
              tooltip: state.panMode ? 'Select' : 'Pan',
              onTap: () => state.setPanMode(!state.panMode),
            ),
            const _NavDivider(),

            // Zoom out
            _NavButton(
              icon: Icons.zoom_out,
              onTap: state.zoomOut,
            ),
            // Zoom %
            SizedBox(
              width: 36,
              child: Text(
                '${state.zoom.round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0x8C000000)),
              ),
            ),
            // Zoom in
            _NavButton(
              icon: Icons.zoom_in,
              onTap: state.zoomIn,
            ),
            // Fit
            _NavButton(
              icon: Icons.fit_screen,
              tooltip: 'Fit to view',
              onTap: () {
                // context.findRenderObject() is the Center pill widget (~44 px
                // tall). Its parent in the render tree is the workspace Stack —
                // the correct size to pass to fitToView.
                final parent = context.findRenderObject()?.parent;
                if (parent is RenderBox) {
                  state.fitToView(parent.size.width, parent.size.height);
                }
              },
            ),

            const _NavDivider(),

            // Grid (right-click = pitch dialog)
            _NavButton(
              icon: Icons.grid_on_outlined,
              active: state.gridEnabled,
              tooltip: 'Toggle grid  •  Right-click: set pitch',
              onTap: state.toggleGrid,
              onSecondaryTap: () => _showGridPitchDialog(context, state),
            ),
            // Snap
            _NavButton(
              icon: Icons.near_me,
              active: state.snapEnabled,
              tooltip: 'Toggle snap',
              onTap: state.toggleSnap,
            ),

            const _NavDivider(),

            // Section layout vs free placement
            _NavButton(
              icon: Icons.view_agenda_outlined,
              active: state.sectionLayoutEnabled,
              tooltip: state.sectionLayoutEnabled
                  ? 'Section layout on — rows/cols flow at top'
                  : 'Free layout — place rows/cols anywhere',
              onTap: state.toggleSectionLayout,
            ),

            const _NavDivider(),

            // Print
            _NavButton(
              icon: Icons.print_outlined,
              tooltip: 'Print',
              onTap: onPrint,
            ),
          ]),
        ),
      ),
    );
  }
}

void _showGridPitchDialog(BuildContext context, dynamic state) {
  double pitch = state.gridPitch as double;
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Grid Pitch'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${pitch.round()} px',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Slider(
            value: pitch,
            min: 2,
            max: 100,
            divisions: 49,
            label: '${pitch.round()} px',
            onChanged: (v) => setState(() => pitch = v),
          ),
          const Text('Drag to set the grid cell size',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              state.setGridPitch(pitch);
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    ),
  );
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final bool active;
  final bool disabled;
  final String? tooltip;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;

  const _NavButton({
    required this.icon,
    this.active = false,
    this.disabled = false,
    this.tooltip,
    this.onTap,
    this.onSecondaryTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Opacity(
          opacity: widget.disabled ? 0.3 : 1.0,
          child: GestureDetector(
            onTap: widget.disabled ? null : widget.onTap,
            onSecondaryTap: widget.disabled ? null : widget.onSecondaryTap,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.active
                    ? AppColors.accent
                    : (_hovered ? const Color(0x14000000) : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 14,
                color: widget.active
                    ? AppColors.accentForeground
                    : withAlpha(AppColors.foreground, _hovered ? 1 : 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: const Color(0x1A000000),
    );
  }
}
