import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/element_model.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';

class EditorToolbar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onPreview;
  final VoidCallback onExportPdf;

  const EditorToolbar({
    super.key,
    required this.onBack,
    required this.onPreview,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final template = state.template;

    return SizedBox(
      height: 52,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xEEFFFFFF), // ~93% white
              border: Border(bottom: BorderSide(color: Color(0x0F000000))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              // Back / template name
              _ToolButton(
                onTap: onBack,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chevron_left, size: 14, color: AppColors.mutedForeground),
                  const SizedBox(width: 4),
                  if (template != null)
                    Text(template.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground)),
                ]),
              ),

              const Spacer(),

              // Insert group
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: withAlpha(AppColors.secondary, 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  // Select tool (always active — default interaction mode)
                  _InsertButton(
                    icon: Icons.near_me_outlined,
                    tooltip: 'Select',
                    active: true,
                    onTap: () {},
                  ),
                  const _ToolDivider(),
                  const _GroupLabel('PRIMITIVES'),
                  _InsertButton(
                    icon: Icons.text_fields,
                    tooltip: 'Text',
                    onTap: () => state.addElement(TextElement.create()),
                  ),
                  _InsertButton(
                    icon: Icons.crop_square,
                    tooltip: 'Rectangle',
                    onTap: () => state.addElement(ShapeElement.create('rectangle')),
                  ),
                  _InsertButton(
                    icon: Icons.circle_outlined,
                    tooltip: 'Circle',
                    onTap: () => state.addElement(ShapeElement.create('circle')),
                  ),
                  _InsertButton(
                    icon: Icons.remove,
                    tooltip: 'Line',
                    onTap: () => state.addElement(ShapeElement.create('line')),
                  ),
                  _InsertButton(
                    icon: Icons.image_outlined,
                    tooltip: 'Image',
                    onTap: () => state.addElement(ImageElement.create()),
                  ),
                  _InsertButton(
                    icon: Icons.qr_code,
                    tooltip: 'QR Code',
                    onTap: () => state.addElement(QrElement.create()),
                  ),
                  _InsertButton(
                    icon: Icons.bar_chart,
                    tooltip: 'Barcode',
                    onTap: () => state.addElement(BarcodeElement.create()),
                  ),
                  const _ToolDivider(),
                  const _GroupLabel('LAYOUT'),
                  _InsertButton(
                    icon: Icons.table_rows_outlined,
                    tooltip: state.sectionLayoutEnabled
                        ? 'Row section (flows at top)'
                        : 'Row (free placement)',
                    onTap: () => state.addLayoutContainer('row'),
                  ),
                  _InsertButton(
                    icon: Icons.view_column_outlined,
                    tooltip: state.sectionLayoutEnabled
                        ? 'Column section (flows at top)'
                        : 'Column (free placement)',
                    onTap: () => state.addLayoutContainer('col'),
                  ),
                ]),
              ),

              const Spacer(),

              // Undo / Redo
              _IconToolButton(
                icon: Icons.undo,
                tooltip: 'Undo  Ctrl+Z',
                enabled: state.canUndo,
                onTap: state.undo,
              ),
              _IconToolButton(
                icon: Icons.redo,
                tooltip: 'Redo  Ctrl+Y',
                enabled: state.canRedo,
                onTap: state.redo,
              ),

              const _Divider(),

              // Preview toggle
              _PreviewToggle(
                active: state.previewMode,
                onTap: () => state.setPreviewMode(!state.previewMode),
              ),

              const SizedBox(width: 6),

              // Export PDF
              _OutlineButton(
                icon: Icons.download_outlined,
                label: 'Export',
                tooltip: 'Export PDF',
                onTap: onExportPdf,
              ),

              const SizedBox(width: 6),

              // Save
              GestureDetector(
                onTap: state.saving ? null : state.save,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: withAlpha(AppColors.foreground, state.saving ? 0.4 : 1.0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.saving ? 'Saving…' : 'Save',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.card,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Group label (PRIMITIVES / LAYOUT) ────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.07,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

// ── Thin vertical divider inside insert group ─────────────────────────────────

class _ToolDivider extends StatelessWidget {
  const _ToolDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 16,
      child: VerticalDivider(color: Color(0x1A000000)),
    );
  }
}

// ── Insert button ─────────────────────────────────────────────────────────────

class _InsertButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final bool active;

  const _InsertButton({
    required this.icon,
    this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  State<_InsertButton> createState() => _InsertButtonState();
}

class _InsertButtonState extends State<_InsertButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active
                  ? withAlpha(AppColors.accent, 0.12)
                  : (_hovered ? const Color(0x14000000) : Colors.transparent),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: active
                  ? AppColors.accent
                  : (_hovered ? AppColors.foreground : withAlpha(AppColors.foreground, 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Icon tool button (undo/redo) ──────────────────────────────────────────────

class _IconToolButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _IconToolButton({
    required this.icon,
    this.tooltip,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.2,
        child: IconButton(
          icon: Icon(icon, size: 14),
          onPressed: enabled ? onTap : null,
          iconSize: 14,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

// ── Generic tap button wrapper ────────────────────────────────────────────────

class _ToolButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _ToolButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: child,
      ),
    );
  }
}

// ── Section divider ───────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 16,
      child: VerticalDivider(color: Color(0x1A000000)),
    );
  }
}

// ── Preview toggle ────────────────────────────────────────────────────────────

class _PreviewToggle extends StatefulWidget {
  final bool active;
  final VoidCallback onTap;
  const _PreviewToggle({required this.active, required this.onTap});

  @override
  State<_PreviewToggle> createState() => _PreviewToggleState();
}

class _PreviewToggleState extends State<_PreviewToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return Tooltip(
      message: active ? 'Exit Preview' : 'Preview with data',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent
                  : (_hovered ? const Color(0x12000000) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: active ? null : Border.all(color: const Color(0x1A000000)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                active ? Icons.visibility : Icons.visibility_outlined,
                size: 13,
                color: active
                    ? AppColors.accentForeground
                    : withAlpha(AppColors.foreground, 0.7),
              ),
              const SizedBox(width: 5),
              Text(
                'Preview',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: active
                      ? AppColors.accentForeground
                      : withAlpha(AppColors.foreground, 0.7),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Outline button (Export) ───────────────────────────────────────────────────

class _OutlineButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onTap;
  const _OutlineButton(
      {required this.icon,
      required this.label,
      this.tooltip,
      required this.onTap});

  @override
  State<_OutlineButton> createState() => _OutlineButtonState();
}

class _OutlineButtonState extends State<_OutlineButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered ? const Color(0x12000000) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1A000000)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon,
                  size: 13, color: withAlpha(AppColors.foreground, 0.7)),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: withAlpha(AppColors.foreground, 0.7))),
            ]),
          ),
        ),
      ),
    );
  }
}
