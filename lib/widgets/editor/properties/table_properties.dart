import 'package:flutter/material.dart';

import '../../../models/element_model.dart';
import '../../../theme/app_colors.dart';

/// Inspector for a [TableElement] — the bound list, and the columns.
///
/// Lives in its own file because `properties_panel.dart` is already past 1300
/// lines and a column editor is not small.
class TableProperties extends StatelessWidget {
  final TableElement el;
  final void Function(CanvasElement) update;

  const TableProperties({super.key, required this.el, required this.update});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Data list'),
        const SizedBox(height: 4),
        _Text(
          value: el.rowSource,
          hint: 'invoice.lines',
          onChanged: (v) => update(el.copyWith(rowSource: v)),
        ),
        const _Hint(
            'Key on the print record holding the rows, e.g. invoice.lines'),
        const SizedBox(height: 12),

        const _Label('Columns from data (optional)'),
        const SizedBox(height: 4),
        _Text(
          value: el.columnsFrom,
          hint: 'report.columns',
          onChanged: (v) => update(el.copyWith(columnsFrom: v)),
        ),
        const _Hint('For reports whose columns are only known when printed. '
            'Ignored when columns are set below.'),
        const SizedBox(height: 16),

        Row(
          children: [
            const Expanded(child: _Label('Columns')),
            TextButton.icon(
              onPressed: () => update(el.copyWith(
                columns: [...el.columns, const TableColumn(key: 'field')],
              )),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add'),
            ),
          ],
        ),
        if (el.columns.isEmpty)
          const _Hint('No columns — they will be derived from the first row of '
              'the data, using the field names as headers.'),
        for (var i = 0; i < el.columns.length; i++)
          _ColumnRow(
            column: el.columns[i],
            onChanged: (c) {
              final next = [...el.columns]..[i] = c;
              update(el.copyWith(columns: next));
            },
            onRemove: () {
              final next = [...el.columns]..removeAt(i);
              update(el.copyWith(columns: next));
            },
            onMoveUp: i == 0
                ? null
                : () {
                    final next = [...el.columns];
                    next.insert(i - 1, next.removeAt(i));
                    update(el.copyWith(columns: next));
                  },
          ),

        const SizedBox(height: 16),
        _Check(
          label: 'Show header row',
          value: el.showHeader,
          onChanged: (v) => update(el.copyWith(showHeader: v)),
        ),
        _Check(
          label: 'Zebra striping',
          value: el.zebra,
          onChanged: (v) => update(el.copyWith(zebra: v)),
        ),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Row height'),
              _Num(
                value: el.rowHeight,
                onChanged: (v) => update(el.copyWith(rowHeight: v)),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Font size'),
              _Num(
                value: el.fontSize,
                onChanged: (v) => update(el.copyWith(fontSize: v)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        const _Label('Max rows'),
        _Num(
          value: el.maxRows.toDouble(),
          onChanged: (v) => update(el.copyWith(maxRows: v.round())),
        ),
        const _Hint('0 = no limit. A table that flows will run onto the next '
            'page rather than lose rows. When a limit is set, hidden rows are '
            'reported as "+N more" instead of disappearing.'),
        const SizedBox(height: 12),

        const _Label('Text when empty'),
        const SizedBox(height: 4),
        _Text(
          value: el.emptyText,
          hint: 'No items.',
          onChanged: (v) => update(el.copyWith(emptyText: v)),
        ),
      ],
    );
  }
}

class _ColumnRow extends StatelessWidget {
  final TableColumn column;
  final ValueChanged<TableColumn> onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;

  const _ColumnRow({
    required this.column,
    required this.onChanged,
    required this.onRemove,
    this.onMoveUp,
  });

  TableColumn _with({String? key, String? label, double? flex, String? align}) =>
      TableColumn(
        key: key ?? column.key,
        label: label ?? column.label,
        flex: flex ?? column.flex,
        width: column.width,
        align: align ?? column.align,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _Text(
              value: column.label,
              hint: 'Header',
              onChanged: (v) => onChanged(_with(label: v)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 14),
            onPressed: onMoveUp,
            tooltip: 'Move up',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: onRemove,
            tooltip: 'Remove column',
          ),
        ]),
        const SizedBox(height: 6),
        _Text(
          value: column.key,
          hint: 'field name, or {{token}}',
          onChanged: (v) => onChanged(_with(key: v)),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _Num(
              value: column.flex,
              onChanged: (v) => onChanged(_with(flex: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: SegmentedButton<String>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left, size: 14)),
                ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center, size: 14)),
                ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right, size: 14)),
              ],
              selected: {column.align},
              onSelectionChanged: (s) => onChanged(_with(align: s.first)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Small shared inputs ──────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedForeground)),
      );
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 10, color: AppColors.mutedForeground)),
      );
}

class _Text extends StatefulWidget {
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;

  const _Text({required this.value, required this.hint, required this.onChanged});

  @override
  State<_Text> createState() => _TextState();
}

class _TextState extends State<_Text> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_Text old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: widget.hint,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      );
}

class _Num extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _Num({required this.value, required this.onChanged});

  @override
  State<_Num> createState() => _NumState();
}

class _NumState extends State<_Num> {
  late final TextEditingController _c =
      TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void didUpdateWidget(_Num old) {
    super.didUpdateWidget(old);
    if (_fmt(widget.value) != _c.text) _c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        style: const TextStyle(fontSize: 12),
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(),
        ),
        onChanged: (v) {
          final d = double.tryParse(v);
          if (d != null) widget.onChanged(d);
        },
      );
}

class _Check extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Check({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => onChanged(v ?? false),
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );
}
