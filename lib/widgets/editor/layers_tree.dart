import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/element_model.dart';
import '../../models/layout_helpers.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import '../common/paper_chrome.dart';

class LayersTree extends StatelessWidget {
  const LayersTree({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<EditorState>();
    final sorted = [...state.elements]
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    final sectionLayout = state.sectionLayoutEnabled;

    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: PaperFieldLabel('Layers'),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            children: sorted
                .map((e) => _TreeNode(
                      el: e,
                      depth: 0,
                      sectionLayoutEnabled: sectionLayout,
                      selectedId: state.selectedId,
                      selectedChildId: state.selectedChildId,
                      onSelect: (id, isChild) {
                        if (isChild) {
                          state.selectChild(id);
                        } else {
                          state.select(id);
                        }
                      },
                      onDelete: (id) => state.deleteElement(id),
                      onAddChild: (containerId, child) =>
                          state.addChildToContainer(containerId, child),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}

class _TreeNode extends StatefulWidget {
  final CanvasElement el;
  final int depth;
  final bool sectionLayoutEnabled;
  final String? selectedId;
  final String? selectedChildId;
  final void Function(String id, bool isChild) onSelect;
  final void Function(String id) onDelete;
  final void Function(String containerId, CanvasElement child) onAddChild;

  const _TreeNode({
    required this.el,
    required this.depth,
    required this.sectionLayoutEnabled,
    required this.selectedId,
    required this.selectedChildId,
    required this.onSelect,
    required this.onDelete,
    required this.onAddChild,
  });

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool _expanded = true;
  bool _hovered = false;

  bool get isSelected =>
      widget.el.id == widget.selectedId ||
      widget.el.id == widget.selectedChildId;

  bool get isContainer => widget.el is ContainerElement;

  @override
  Widget build(BuildContext context) {
    final hasChildren =
        widget.el is ContainerElement &&
        (widget.el as ContainerElement).children.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onSelect(widget.el.id, widget.depth > 0),
          child: Container(
            padding: EdgeInsets.only(
                left: 8 + widget.depth * 14.0,
                right: 4,
                top: 4,
                bottom: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.secondary
                  : (_hovered
                      ? withAlpha(AppColors.secondary, 0.6)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              // Expand toggle or spacer
              if (hasChildren)
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 10,
                    color: AppColors.mutedForeground,
                  ),
                )
              else
                const SizedBox(width: 10),
              const SizedBox(width: 4),
              // Type icon
              Icon(_typeIcon(widget.el.type),
                  size: 11, color: AppColors.mutedForeground),
              const SizedBox(width: 4),
              // Name
              Expanded(
                child: Text(
                  _nodeName(widget.el),
                  style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              // Lock icon
              if (widget.el is ContainerElement &&
                  (widget.el as ContainerElement).locked)
                const Icon(Icons.lock_outline,
                    size: 9, color: AppColors.warning),
              // Actions on hover
              if (_hovered || isSelected) ...[
                const SizedBox(width: 2),
                // + button for containers
                if (isContainer)
                  _AddChildButton(
                    containerId: widget.el.id,
                    parentType: widget.el.type,
                    freePlacement: (widget.el as ContainerElement).freePlacement,
                    sectionLayoutEnabled: widget.sectionLayoutEnabled,
                    onAdd: widget.onAddChild,
                  ),
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: () => widget.onDelete(widget.el.id),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.delete_outline,
                        size: 9, color: AppColors.destructive),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
      // Children
      if (hasChildren && _expanded)
        ...(widget.el as ContainerElement).children.map(
          (child) => _TreeNode(
            el: child,
            depth: widget.depth + 1,
            sectionLayoutEnabled: widget.sectionLayoutEnabled,
            selectedId: widget.selectedId,
            selectedChildId: widget.selectedChildId,
            onSelect: widget.onSelect,
            onDelete: widget.onDelete,
            onAddChild: widget.onAddChild,
          ),
        ),
    ]);
  }

  IconData _typeIcon(String type) => switch (type) {
        'text' => Icons.text_fields,
        'shape' => Icons.crop_square,
        'image' => Icons.image_outlined,
        'qr' => Icons.qr_code,
        'barcode' => Icons.bar_chart,
        'row' => Icons.table_rows_outlined,
        'col' => Icons.view_column_outlined,
        'table' => Icons.table_rows_outlined,
        _ => Icons.square_outlined,
      };

  String _nodeName(CanvasElement el) {
    if (el is TextElement) {
      return el.content.length > 18
          ? el.content.substring(0, 18)
          : el.content;
    }
    if (el is ShapeElement) return el.shape;
    if (el is ContainerElement) {
      final label = el.type == 'row' ? 'Row' : 'Column';
      return el.isSection ? '$label (section)' : label;
    }
    return switch (el.type) {
      'image' => 'Image',
      'qr' => 'QR Code',
      'barcode' => 'Barcode',
      'table' => 'Table',
      _ => el.type,
    };
  }
}

// ── Add child button ──────────────────────────────────────────────────────────

class _AddChildButton extends StatelessWidget {
  final String containerId;
  final String parentType; // 'row' | 'col'
  final bool freePlacement;
  final bool sectionLayoutEnabled;
  final void Function(String containerId, CanvasElement child) onAdd;

  const _AddChildButton({
    required this.containerId,
    required this.parentType,
    required this.freePlacement,
    required this.sectionLayoutEnabled,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: withAlpha(AppColors.accent, 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.add, size: 11, color: AppColors.accent),
      ),
    );
  }

  void _showMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final canAddRow = canAddRowToParent(
      parentType: parentType,
      parentFreePlacement: freePlacement,
      sectionLayoutEnabled: sectionLayoutEnabled,
    );
    final canAddCol = canAddColToParent(
      parentType: parentType,
      parentFreePlacement: freePlacement,
      sectionLayoutEnabled: sectionLayoutEnabled,
    );

    final primitiveItems = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'text',    height: 32, child: _MenuRow(icon: Icons.text_fields,       label: 'Text')),
      const PopupMenuItem(value: 'rect',    height: 32, child: _MenuRow(icon: Icons.crop_square,       label: 'Rectangle')),
      const PopupMenuItem(value: 'circle',  height: 32, child: _MenuRow(icon: Icons.circle_outlined,   label: 'Circle')),
      const PopupMenuItem(value: 'line',    height: 32, child: _MenuRow(icon: Icons.horizontal_rule,   label: 'Line')),
      const PopupMenuItem(value: 'image',   height: 32, child: _MenuRow(icon: Icons.image_outlined,    label: 'Image')),
      const PopupMenuItem(value: 'qr',      height: 32, child: _MenuRow(icon: Icons.qr_code,           label: 'QR Code')),
      const PopupMenuItem(value: 'barcode', height: 32, child: _MenuRow(icon: Icons.bar_chart,         label: 'Barcode')),
    ];

    final containerItems = <PopupMenuEntry<String>>[
      const PopupMenuDivider(),
      if (canAddRow)
        const PopupMenuItem(value: 'row', height: 32,
            child: _MenuRow(icon: Icons.table_rows_outlined,  label: 'Row')),
      if (canAddCol)
        const PopupMenuItem(value: 'col', height: 32,
            child: _MenuRow(icon: Icons.view_column_outlined, label: 'Column')),
    ];

    final screenSize = MediaQuery.sizeOf(context);
    final result = await showMenu<String>(
      context: context,
      color: AppColors.card,
      // RelativeRect right/bottom are distances FROM the screen edges, not
      // absolute coords — use fromRect to avoid the menu appearing at (0,0).
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          offset.dx,
          offset.dy + box.size.height + 4,
          160,
          260,
        ),
        Offset.zero & screenSize,
      ),
      items: [...primitiveItems, ...containerItems],
    );

    if (result == null) return;
    final child = _makeChild(result);
    if (child != null) onAdd(containerId, child);
  }

  CanvasElement? _makeChild(String type) => switch (type) {
        'text' => TextElement.createChild(),
        'rect' => ShapeElement.createChild('rect'),
        'circle' => ShapeElement.createChild('circle'),
        'line' => ShapeElement.createChild('line'),
        'image' => ImageElement.createChild(),
        'qr' => QrElement.createChild(),
        'barcode' => BarcodeElement.createChild(),
        'row' => ContainerElement.createChild('row'),
        'col' => ContainerElement.createChild('col'),
        _ => null,
      };
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: AppColors.mutedForeground),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
