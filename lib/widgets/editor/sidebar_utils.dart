import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Collapsed sidebar pill (replaces the sidebar when closed)
class SidebarPill extends StatelessWidget {
  final String label;
  final String side; // 'left' | 'right'
  final VoidCallback onTap;

  const SidebarPill({super.key, required this.label, required this.side, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 24,
          decoration: BoxDecoration(
            color: AppColors.panelBg,
            border: side == 'left'
                ? Border(right: BorderSide(color: AppColors.border))
                : Border(left: BorderSide(color: AppColors.border)),
          ),
          child: Center(
            child: RotatedBox(
              quarterTurns: side == 'left' ? 3 : 1,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.08,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Sidebar with draggable resize handle on one edge
class ResizableSidebar extends StatefulWidget {
  final double width;
  final String side; // 'left' | 'right' — which edge has the resize handle
  final void Function(double) onWidthChanged;
  final Widget child;

  const ResizableSidebar({
    super.key,
    required this.width,
    required this.side,
    required this.onWidthChanged,
    required this.child,
  });

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  bool _hoveringHandle = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Stack(children: [
        widget.child,
        Positioned(
          top: 0,
          bottom: 0,
          right: widget.side == 'right' ? 0 : null,
          left: widget.side == 'left' ? 0 : null,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            onEnter: (_) => setState(() => _hoveringHandle = true),
            onExit: (_) => setState(() => _hoveringHandle = false),
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                final delta = widget.side == 'right' ? d.delta.dx : -d.delta.dx;
                final newW = (widget.width + delta).clamp(180.0, 380.0);
                widget.onWidthChanged(newW);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 4,
                color: _hoveringHandle ? withAlpha(AppColors.accent, 0.5) : Colors.transparent,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
