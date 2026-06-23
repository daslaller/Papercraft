import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/element_model.dart';
import '../../services/token_service.dart';
import '../../state/editor_state.dart';
import '../../theme/app_colors.dart';
import 'sidebar_utils.dart';

// ── Mock preview records ─────────────────────────────────────────────────────

class _PreviewRecord {
  final String displayName;
  final String subtitle;
  final Map<String, String> values;
  const _PreviewRecord({required this.displayName, required this.subtitle, required this.values});
}

const _kMockRecords = [
  _PreviewRecord(
    displayName: 'Aurora Lamp',
    subtitle: 'sku LMP-204',
    values: {
      'id': 'REC-001',
      'name': 'Aurora Lamp',
      'sku': 'LMP-204',
      'price': r'$48.00',
      'email': 'aurora@example.com',
      'quantity': '12',
      'address': '42 Light Ave',
      'phone': '+1 555-0101',
    },
  ),
  _PreviewRecord(
    displayName: 'Field Notebook',
    subtitle: 'sku NB-011',
    values: {
      'id': 'REC-002',
      'name': 'Field Notebook',
      'sku': 'NB-011',
      'price': r'$24.00',
      'email': 'field@example.com',
      'quantity': '5',
      'address': '14 Pearl Street',
      'phone': '+1 555-0102',
    },
  ),
  _PreviewRecord(
    displayName: 'Cedar Candle',
    subtitle: 'sku CC-033',
    values: {
      'id': 'REC-003',
      'name': 'Cedar Candle',
      'sku': 'CC-033',
      'price': r'$18.00',
      'email': 'cedar@example.com',
      'quantity': '8',
      'address': '7 Oak Street',
      'phone': '+1 555-0103',
    },
  ),
];

const _kFieldDefs = ['id', 'name', 'sku', 'price', 'email', 'quantity', 'address', 'phone'];

// ── Sidebar ───────────────────────────────────────────────────────────────────

class LeftSidebar extends StatefulWidget {
  const LeftSidebar({super.key});

  @override
  State<LeftSidebar> createState() => _LeftSidebarState();
}

class _LeftSidebarState extends State<LeftSidebar> {
  bool _open = true;
  double _width = 240;

  final _entityCtrl = TextEditingController();
  String? _connectedEntity;
  String _search = '';
  int _selectedRecordIdx = 0;

  List<ComputedField> _computed = [];
  final _cfNameCtrl = TextEditingController();
  final _cfFormulaCtrl = TextEditingController();
  String? _cfError;
  bool _showComputed = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<EditorState>();
    _connectedEntity = state.template?.connectedEntity;
    if (_connectedEntity != null) {
      _syncPreviewRecord(state);
      _loadComputed();
    }
  }

  Future<void> _loadComputed() async {
    if (_connectedEntity == null) return;
    final fields = await TokenService.loadComputedFields(_connectedEntity!);
    if (mounted) setState(() => _computed = fields);
  }

  void _syncPreviewRecord(EditorState state) {
    if (_connectedEntity == null) return;
    final record = _kMockRecords[_selectedRecordIdx];
    final nested = {
      _connectedEntity!: {
        for (final e in record.values.entries) e.key: e.value
      }
    };
    state.setPreviewRecord(nested, _connectedEntity!);
  }

  void _connectEntity(EditorState state) {
    final name = _entityCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _connectedEntity = name);
    final template = state.template;
    if (template != null) {
      state.updateTemplate(template.copyWith(connectedEntity: name));
    }
    _syncPreviewRecord(state);
    _loadComputed();
  }

  void _disconnect(EditorState state) {
    setState(() {
      _connectedEntity = null;
      _entityCtrl.clear();
    });
    state.setPreviewRecord(null, null);
    final template = state.template;
    if (template != null) {
      state.updateTemplate(template.copyWith(connectedEntity: null));
    }
  }

  void _selectRecord(int idx, EditorState state) {
    setState(() => _selectedRecordIdx = idx);
    _syncPreviewRecord(state);
  }

  @override
  void dispose() {
    _entityCtrl.dispose();
    _cfNameCtrl.dispose();
    _cfFormulaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return SidebarPill(
        label: 'DATA',
        side: 'left',
        onTap: () => setState(() => _open = true),
      );
    }

    return ResizableSidebar(
      width: _width,
      side: 'right',
      onWidthChanged: (w) => setState(() => _width = w),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    final state = context.watch<EditorState>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelBg,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        _buildHeader(state),
        Expanded(
          child: _connectedEntity == null
              ? _buildConnectView(state)
              : _buildConnectedView(state),
        ),
      ]),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader(EditorState state) {
    if (_connectedEntity == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          const Text('Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.foreground)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _open = false),
            child: const Icon(Icons.close, size: 13, color: AppColors.mutedForeground),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          const Text('Connected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.foreground)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: withAlpha(AppColors.secondary, 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('Mock', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.mutedForeground)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _open = false),
            child: const Icon(Icons.close, size: 13, color: AppColors.mutedForeground),
          ),
        ]),
        const SizedBox(height: 3),
        Text(
          'demo · $_connectedEntity · ${_kFieldDefs.length} fields mapped',
          style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _disconnect(state),
          child: const Text('Disconnect', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444))),
        ),
      ]),
    );
  }

  // ── Connect view (no entity yet) ─────────────────────────────────────────────

  Widget _buildConnectView(EditorState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DATA SOURCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        TextField(
          controller: _entityCtrl,
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            hintText: 'Entity name (e.g. Order)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
          ),
          onSubmitted: (_) => _connectEntity(state),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () => _connectEntity(state),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
              child: const Text('Connect', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentForeground)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Connected view ───────────────────────────────────────────────────────────

  Widget _buildConnectedView(EditorState state) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Preview Records
        _buildPreviewRecords(state),

        const Divider(height: 1, color: AppColors.border),

        // Fields header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            const Text('FIELDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: AppColors.mutedForeground)),
            const SizedBox(width: 6),
            const Expanded(child: Text('Click to add to canvas', style: TextStyle(fontSize: 9, color: AppColors.mutedForeground))),
          ]),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 11, color: AppColors.mutedForeground),
              hintText: 'Search fields…',
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),

        // Field list
        _buildFieldList(state),

        // Computed fields toggle
        _buildComputedSection(state),
      ]),
    );
  }

  Widget _buildPreviewRecords(EditorState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PREVIEW RECORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: AppColors.mutedForeground)),
        const SizedBox(height: 8),
        ..._kMockRecords.asMap().entries.map((entry) {
          final idx = entry.key;
          final rec = entry.value;
          final isSelected = idx == _selectedRecordIdx;
          return GestureDetector(
            onTap: () => _selectRecord(idx, state),
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.accent : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? withAlpha(AppColors.accent, 0.05) : Colors.transparent,
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? withAlpha(AppColors.accent, 0.12) : withAlpha(AppColors.secondary, 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      rec.displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.accent : AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rec.displayName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? AppColors.foreground : AppColors.foreground)),
                    Text(rec.subtitle, style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
                  ]),
                ),
                if (isSelected) Icon(Icons.check, size: 14, color: AppColors.accent),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildFieldList(EditorState state) {
    final selectedEl = state.selectedElement;
    final canInsert = selectedEl is TextElement;
    final selectedRecord = _kMockRecords[_selectedRecordIdx];

    final filtered = _kFieldDefs
        .where((f) => _search.isEmpty ||
            f.toLowerCase().contains(_search.toLowerCase()) ||
            '${_connectedEntity!}.$f'.contains(_search.toLowerCase()))
        .toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No fields match', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 10),
        // Entity group label
        Text(
          _connectedEntity![0].toUpperCase() + _connectedEntity!.substring(1),
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 4),
        ...filtered.map((field) {
          final token = '${_connectedEntity!}.$field';
          final value = selectedRecord.values[field] ?? '';
          return GestureDetector(
            onTap: () {
              if (canInsert) {
                final el = selectedEl as TextElement;
                state.commitUpdate(el.id, el.copyWith(content: '${el.content}{{$token}}'));
              } else {
                final newEl = TextElement.create().copyWith(content: '{{$token}}');
                state.addElement(newEl);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: withAlpha(AppColors.border, 0.7))),
              ),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(token, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.foreground)),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 10, color: AppColors.mutedForeground),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildComputedSection(EditorState state) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 1, color: AppColors.border),
      GestureDetector(
        onTap: () => setState(() => _showComputed = !_showComputed),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Text('COMPUTED FIELDS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: AppColors.mutedForeground)),
            const Spacer(),
            Icon(_showComputed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: AppColors.mutedForeground),
          ]),
        ),
      ),
      if (_showComputed) _buildComputedContent(state),
    ]);
  }

  Widget _buildComputedContent(EditorState state) {
    final canInsert = state.selectedElement is TextElement;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_computed.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No computed fields yet', style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
          )
        else
          ..._computed.asMap().entries.map((entry) {
            final i = entry.key;
            final cf = entry.value;
            return Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: canInsert
                      ? () {
                          final el = state.selectedElement as TextElement;
                          state.commitUpdate(el.id, el.copyWith(content: '${el.content}{{computed:${cf.name}}}'));
                        }
                      : null,
                  child: Opacity(
                    opacity: canInsert ? 1 : 0.5,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cf.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text(cf.formula, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppColors.mutedForeground), overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 11, color: AppColors.destructive),
                onPressed: () async {
                  setState(() => _computed.removeAt(i));
                  if (_connectedEntity != null) await TokenService.saveComputedFields(_connectedEntity!, _computed);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ]);
          }),
        // Add computed field form
        TextField(
          controller: _cfNameCtrl,
          style: const TextStyle(fontSize: 11),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), hintText: 'Field name', border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border))),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _cfFormulaCtrl,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), hintText: '{{entity.qty}} * {{entity.price}}', border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border))),
        ),
        if (_cfError != null) Text(_cfError!, style: const TextStyle(fontSize: 10, color: AppColors.destructive)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _addComputedField,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
              child: const Text('Add field', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accentForeground)),
            ),
          ),
        ),
      ]),
    );
  }

  void _addComputedField() async {
    final name = _cfNameCtrl.text.trim();
    final formula = _cfFormulaCtrl.text.trim();
    if (name.isEmpty || formula.isEmpty) {
      setState(() => _cfError = 'Name and formula are required');
      return;
    }
    if (!TokenService.validateFormula(formula)) {
      setState(() => _cfError = 'Only + − × ÷ and field tokens are allowed');
      return;
    }
    final cf = ComputedField(name: name, formula: formula);
    setState(() { _computed.add(cf); _cfError = null; });
    _cfNameCtrl.clear();
    _cfFormulaCtrl.clear();
    if (_connectedEntity != null) await TokenService.saveComputedFields(_connectedEntity!, _computed);
  }
}

