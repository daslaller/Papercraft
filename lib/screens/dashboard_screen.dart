import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/element_model.dart';
import '../models/template_model.dart';
import '../services/papercraft_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/modals/new_template_modal.dart';
import '../widgets/papercraft_renderer.dart';

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt).inSeconds;
  if (diff < 60) return 'just now';
  if (diff < 3600) return '${diff ~/ 60}m ago';
  if (diff < 86400) return '${diff ~/ 3600}h ago';
  return '${diff ~/ 86400}d ago';
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.ownerId,
    required this.onOpen,
    this.onExit,
    this.showChrome = true,
    this.embedded = false,
    this.appName = 'Papercraft',
    this.logo,
  });

  /// Owner id whose templates are listed/created (host user/tenant id).
  final String ownerId;

  /// Opens a template for editing — the host pushes the editor.
  final void Function(String templateId) onOpen;

  /// Optional exit/back action; the navbar trailing button hides when null.
  final VoidCallback? onExit;

  /// Show the top navbar (brand + actions). False embeds the grid bare.
  final bool showChrome;

  /// Embed the picker inside a host layout: no Scaffold, navbar, or hero, and
  /// no internal scrolling — the filter bar + template grid shrink-wrap so the
  /// host's own scroll view owns scrolling. [showChrome]/[onExit]/[appName]/
  /// [logo] are ignored in this mode.
  final bool embedded;

  /// Brand name shown in the navbar.
  final String appName;

  /// Optional brand logo shown before [appName].
  final Widget? logo;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Template> _templates = [];
  bool _loading = true;
  String _search = '';
  String _filter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = StorageRegistry.active;
    await storage.seedDefaults(widget.ownerId);
    final templates = await storage.list(ownerId: widget.ownerId);
    if (!mounted) return;
    setState(() { _templates = templates; _loading = false; });
  }

  List<Template> get _filtered {
    var list = _templates;
    if (_filter != 'all') list = list.where((t) => t.docType == _filter).toList();
    if (_search.isNotEmpty) {
      list = list.where((t) =>
          t.name.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    return list;
  }

  Future<void> _createTemplate() async {
    final result = await showDialog<Template>(
      context: context,
      builder: (_) => NewTemplateModal(ownerId: widget.ownerId),
    );
    if (result != null) {
      if (!mounted) return;
      widget.onOpen(result.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          const SizedBox(height: 24),
          _buildGrid(),
        ],
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(children: [
        if (widget.showChrome) _buildNavbar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 40),
                    _buildFilterBar(),
                    const SizedBox(height: 32),
                    _buildGrid(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildNavbar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.glassBar,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        widget.logo ??
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.description,
                  size: 16, color: AppColors.primaryForeground),
            ),
        const SizedBox(width: 12),
        Text(widget.appName,
            style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground)),
        const Spacer(),
        _AccentButton(
          onTap: _createTemplate,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add, size: 16, color: AppColors.accentForeground),
            const SizedBox(width: 6),
            const Text('New Template',
                style: TextStyle(
                    color: AppColors.accentForeground,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
        ),
        if (widget.onExit != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onExit,
            icon: const Icon(Icons.close,
                size: 18, color: AppColors.mutedForeground),
            tooltip: 'Close',
          ),
        ],
      ]),
    );
  }

  Widget _buildHero() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your Templates',
          style: GoogleFonts.playfairDisplay(
              fontSize: 36, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('Design beautiful labels and documents connected to live data.',
          style: TextStyle(fontSize: 16, color: AppColors.mutedForeground)),
    ]);
  }

  Widget _buildFilterBar() {
    return Wrap(spacing: 12, runSpacing: 8, children: [
      SizedBox(
        width: 320,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search templates…',
            prefixIcon: const Icon(Icons.search,
                size: 16, color: AppColors.mutedForeground),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      ...['all', 'label', 'document'].map((f) {
        final label = f == 'all' ? 'All' : f == 'label' ? 'Labels' : 'Documents';
        final active = _filter == f;
        return _FilterButton(
          label: label,
          active: active,
          onTap: () => setState(() => _filter = f),
        );
      }),
    ]);
  }

  Widget _buildGrid() {
    // Columns follow the width actually granted to the grid (not the window),
    // so the picker also lays out correctly when embedded in a narrow host
    // column.
    return LayoutBuilder(
      builder: (context, constraints) => _buildGridContent(
        _crossAxisCount(constraints.maxWidth),
      ),
    );
  }

  Widget _buildGridContent(int crossAxisCount) {
    if (_loading) {
      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 4 / 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
            8,
            (_) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                )),
      );
    }

    final items = _filtered;

    if (_templates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 96),
          child: Column(children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.shadowSm),
              child: const Icon(Icons.auto_awesome,
                  size: 32, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text('Create your first template',
                style: GoogleFonts.playfairDisplay(
                    fontSize: 24, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text(
              'Design beautiful labels and documents\nconnected to live data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedForeground,
                  height: 1.6),
            ),
            const SizedBox(height: 32),
            _AccentButton(
              onTap: _createTemplate,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add,
                    size: 16, color: AppColors.accentForeground),
                const SizedBox(width: 8),
                const Text('New Template',
                    style: TextStyle(
                        color: AppColors.accentForeground,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
              ]),
            ),
          ]),
        ),
      );
    }

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 80),
          child: Text('No templates match your search.',
              style: TextStyle(fontSize: 14, color: AppColors.mutedForeground)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 4 / 3,
      ),
      itemCount: items.length + 1,
      itemBuilder: (_, i) {
        if (i == items.length) return _NewTemplateCard(onTap: _createTemplate);
        return _TemplateCard(
          template: items[i],
          onOpen: () => widget.onOpen(items[i].id),
          onDelete: () async {
            await StorageRegistry.active.delete(items[i].id);
            _load();
          },
          onDuplicate: () async {
            final copy = await StorageRegistry.active
                .duplicate(items[i], widget.ownerId);
            if (!mounted) return;
            widget.onOpen(copy.id);
          },
          onRename: (name) async {
            await StorageRegistry.active.save(items[i].copyWith(name: name));
            _load();
          },
          onSetDefault: () async {
            await StorageRegistry.active
                .setDefault(items[i].id, items[i].docType);
            _load();
          },
        );
      },
    );
  }

  int _crossAxisCount(double w) {
    if (w >= 1024) return 4;
    if (w >= 640) return 3;
    return 2;
  }
}

// ── Template Card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final Template template;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final void Function(String) onRename;
  final VoidCallback onSetDefault;

  const _TemplateCard({
    required this.template,
    required this.onOpen,
    required this.onDelete,
    required this.onDuplicate,
    required this.onRename,
    required this.onSetDefault,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _hovered = false;
  bool _renaming = false;
  bool _menuOpen = false;
  final _renameCtrl = TextEditingController();

  @override
  void dispose() {
    _renameCtrl.dispose();
    super.dispose();
  }

  /// Renders a live preview of the template's current layout using
  /// [PapercraftRenderer], falling back to an icon placeholder for empty or
  /// unparseable templates.
  Widget _buildPreview() {
    List<CanvasElement> elements = const [];
    try {
      elements = elementsFromJson(widget.template.elements);
    } catch (_) {}

    if (elements.isEmpty) {
      return Container(
        color: Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.template.docType == 'label'
                  ? Icons.label
                  : Icons.description,
              size: 28,
              color: AppColors.mutedForeground.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.template.canvasWidthMm.toStringAsFixed(0)}'
              '×${widget.template.canvasHeightMm.toStringAsFixed(0)} mm',
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: PapercraftRenderer.fitted(
        template: widget.template,
        elements: elements,
        maxScale: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: _hovered ? AppColors.shadowLg : [],
          ),
          transform: _hovered
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          child: Column(children: [
            // Preview area
            Expanded(
              child: Stack(children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.workspaceBg,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildPreview(),
                  ),
                ),
                // Type badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.template.docType == 'label'
                          ? withAlpha(AppColors.accent, 0.15)
                          : withAlpha(AppColors.primary, 0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      widget.template.docType == 'label' ? 'Label' : 'Document',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.05,
                        color: widget.template.docType == 'label'
                            ? AppColors.accent
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // Default badge — shown when this template is the explicit default
                if (widget.template.isDefault)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 8,
                              color: AppColors.accentForeground),
                          SizedBox(width: 3),
                          Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ]),
            ),
            // Footer
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _renaming
                          ? TextField(
                              controller: _renameCtrl,
                              autofocus: true,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.accent),
                                ),
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                              onSubmitted: (v) {
                                if (v.trim().isNotEmpty) {
                                  widget.onRename(v.trim());
                                }
                                setState(() => _renaming = false);
                              },
                              onEditingComplete: () =>
                                  setState(() => _renaming = false),
                            )
                          : Text(
                              widget.template.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.foreground),
                              overflow: TextOverflow.ellipsis,
                            ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 9, color: AppColors.mutedForeground),
                        const SizedBox(width: 4),
                        Text(
                          _timeAgo(widget.template.updatedDate),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.mutedForeground),
                        ),
                        if (widget.template.connectedEntity != null) ...[
                          const Text(' · ',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mutedForeground)),
                          Text(
                            widget.template.connectedEntity!,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
                // Context menu
                _CardMenu(
                  visible: _hovered || _menuOpen,
                  isDefault: widget.template.isDefault,
                  onMenuChange: (open) =>
                      setState(() => _menuOpen = open),
                  onRename: () {
                    _renameCtrl.text = widget.template.name;
                    setState(() => _renaming = true);
                  },
                  onDuplicate: widget.onDuplicate,
                  onDelete: widget.onDelete,
                  onSetDefault: widget.onSetDefault,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CardMenu extends StatefulWidget {
  final bool visible;
  final bool isDefault;
  final void Function(bool) onMenuChange;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onSetDefault;

  const _CardMenu({
    required this.visible,
    required this.isDefault,
    required this.onMenuChange,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  State<_CardMenu> createState() => _CardMenuState();
}

class _CardMenuState extends State<_CardMenu> {
  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onOpen: () => widget.onMenuChange(true),
      onClose: () => widget.onMenuChange(false),
      menuChildren: [
        MenuItemButton(
          onPressed: widget.isDefault ? null : widget.onSetDefault,
          leadingIcon: Icon(
            widget.isDefault
                ? Icons.star_rounded
                : Icons.star_border_rounded,
            size: 12,
            color: widget.isDefault
                ? AppColors.accent
                : AppColors.mutedForeground,
          ),
          child: Text(
            widget.isDefault ? 'Default (active)' : 'Set as default',
            style: TextStyle(
              fontSize: 12,
              color: widget.isDefault
                  ? AppColors.mutedForeground
                  : null,
            ),
          ),
        ),
        MenuItemButton(
          onPressed: widget.onDuplicate,
          leadingIcon: const Icon(Icons.copy, size: 12),
          child: const Text('Duplicate', style: TextStyle(fontSize: 12)),
        ),
        MenuItemButton(
          onPressed: widget.onRename,
          leadingIcon: const Icon(Icons.edit, size: 12),
          child: const Text('Rename', style: TextStyle(fontSize: 12)),
        ),
        const Divider(height: 1),
        MenuItemButton(
          onPressed: widget.onDelete,
          leadingIcon: const Icon(Icons.delete, size: 12,
              color: AppColors.destructive),
          child: const Text('Delete',
              style: TextStyle(fontSize: 12, color: AppColors.destructive)),
        ),
      ],
      builder: (_, controller, __) => AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.more_horiz,
                size: 14, color: AppColors.mutedForeground),
          ),
        ),
      ),
    );
  }
}

class _NewTemplateCard extends StatefulWidget {
  final VoidCallback onTap;
  const _NewTemplateCard({required this.onTap});

  @override
  State<_NewTemplateCard> createState() => _NewTemplateCardState();
}

class _NewTemplateCardState extends State<_NewTemplateCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? AppColors.accent : AppColors.border,
              width: 2,
              style: BorderStyle.solid,
            ),
            color: _hovered
                ? withAlpha(AppColors.accent, 0.05)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered
                      ? withAlpha(AppColors.accent, 0.15)
                      : AppColors.secondary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Icon(Icons.add,
                    size: 20,
                    color: _hovered
                        ? AppColors.accent
                        : AppColors.mutedForeground),
              ),
              const SizedBox(height: 12),
              Text('New Template',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _hovered
                          ? AppColors.accent
                          : AppColors.mutedForeground)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _AccentButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  const _AccentButton({
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                active ? AppColors.primaryForeground : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
