import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

// Floating pill to reopen a collapsed sidebar. Positioned in the canvas Stack.
class FloatingSidebarPill extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const FloatingSidebarPill({super.key, required this.icon, required this.onTap});

  @override
  State<FloatingSidebarPill> createState() => _FloatingSidebarPillState();
}

class _FloatingSidebarPillState extends State<FloatingSidebarPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hovered ? AppColors.card : withAlpha(AppColors.card, 0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.shadowLg,
          ),
          child: Icon(widget.icon, size: 14, color: AppColors.mutedForeground),
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
