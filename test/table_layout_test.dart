import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/papercraft.dart';

TableElement _table({
  List<TableColumn> columns = const [],
  String rowSource = 'lines',
  String columnsFrom = '',
  int maxRows = 0,
}) =>
    TableElement(
      id: 't',
      rowSource: rowSource,
      columnsFrom: columnsFrom,
      columns: columns,
      maxRows: maxRows,
    );

void main() {
  group('resolveTable columns', () {
    test('authored columns win over everything else', () {
      final t = resolveTable(
        _table(columns: const [TableColumn(key: 'a', label: 'A')]),
        {
          'lines': [
            {'a': '1', 'b': '2'}
          ],
        },
      );

      expect(t.columns.map((c) => c.key), ['a']);
      expect(t.cells, [
        ['1']
      ]);
    });

    test('columnsFrom lets the record define columns at print time', () {
      // This is what the generic report export and the bulk list print need:
      // the columns are not known when the template is authored.
      final t = resolveTable(
        _table(columnsFrom: 'report.columns'),
        {
          'report.columns': [
            {'key': 'day', 'label': 'Day'},
            {'key': 'revenue', 'label': 'Revenue', 'align': 'right'},
          ],
          'lines': [
            {'day': '2026-08-01', 'revenue': '1 204,00 kr'}
          ],
        },
      );

      expect(t.columns.map((c) => c.key), ['day', 'revenue']);
      expect(t.columns[1].align, 'right');
      expect(t.cells, [
        ['2026-08-01', '1 204,00 kr']
      ]);
    });

    test('with no columns at all, derives them from the first row', () {
      final t = resolveTable(_table(), {
        'lines': [
          {'unit_price': '10', 'qty': '2'}
        ],
      });

      expect(t.columns.map((c) => c.key), ['unit_price', 'qty']);
      // Humanised, so an unconfigured table still reads as deliberate.
      expect(t.columns.map((c) => c.label), ['Unit Price', 'Qty']);
    });
  });

  group('resolveTable rows', () {
    test('a missing or non-list source yields no rows, never throws', () {
      expect(resolveTable(_table(), null).isEmpty, isTrue);
      expect(resolveTable(_table(), {}).isEmpty, isTrue);
      expect(resolveTable(_table(), {'lines': 'not a list'}).isEmpty, isTrue);
      expect(resolveTable(_table(), {'lines': []}).isEmpty, isTrue);
    });

    test('a cell missing from a row renders empty, not "null"', () {
      final t = resolveTable(
        _table(columns: const [
          TableColumn(key: 'a'),
          TableColumn(key: 'missing'),
        ]),
        {
          'lines': [
            {'a': '1'}
          ],
        },
      );

      expect(t.cells, [
        ['1', '']
      ]);
    });

    test('a token column resolves against the row merged over the record', () {
      final t = resolveTable(
        _table(columns: const [TableColumn(key: '{{qty}} × {{currency}}')]),
        {
          'currency': 'kr',
          'lines': [
            {'qty': '3'}
          ],
        },
      );

      expect(t.cells, [
        ['3 × kr']
      ]);
    });
  });

  group('maxRows', () {
    test('defaults to no cap — a table that flows must not drop rows', () {
      final rows = List.generate(50, (i) => {'a': '$i'});
      final t = resolveTable(_table(columns: const [TableColumn(key: 'a')]),
          {'lines': rows});

      expect(t.cells.length, 50);
      expect(t.overflow, isNull);
    });

    test('when capped, the hidden rows are STATED rather than dropped', () {
      // A clipped table that says nothing reads as a complete one, and an
      // invoice silently losing its last lines is worse than one running long.
      final rows = List.generate(10, (i) => {'a': '$i'});
      final t = resolveTable(
        _table(columns: const [TableColumn(key: 'a')], maxRows: 4),
        {'lines': rows},
      );

      expect(t.cells.length, 4);
      expect(t.overflow, '+6 more');
    });

    test('no overflow label when the rows fit exactly', () {
      final rows = List.generate(4, (i) => {'a': '$i'});
      final t = resolveTable(
        _table(columns: const [TableColumn(key: 'a')], maxRows: 4),
        {'lines': rows},
      );

      expect(t.overflow, isNull);
    });
  });

  group('columnWidths', () {
    test('splits by flex when no column is fixed', () {
      final w = columnWidths(
        const [TableColumn(key: 'a', flex: 3), TableColumn(key: 'b', flex: 1)],
        400,
      );
      expect(w, [300, 100]);
    });

    test('fixed columns are taken out first, the rest split what remains', () {
      final w = columnWidths(
        const [
          TableColumn(key: 'a', width: 100),
          TableColumn(key: 'b', flex: 1),
          TableColumn(key: 'c', flex: 3),
        ],
        500,
      );
      expect(w, [100, 100, 300]);
    });

    test('does not go negative when fixed columns exceed the width', () {
      final w = columnWidths(
        const [TableColumn(key: 'a', width: 600), TableColumn(key: 'b')],
        400,
      );
      expect(w, [600, 0]);
    });
  });

  group('serialization', () {
    test('a table round-trips through JSON', () {
      const original = TableElement(
        id: 'lines',
        isSection: true,
        rowSource: 'invoice.lines',
        columns: [
          TableColumn(key: 'description', label: 'Description', flex: 4),
          TableColumn(key: 'amount', label: 'Amount', width: 80, align: 'right'),
        ],
        zebra: true,
        maxRows: 12,
      );

      final restored = TableElement.fromJson(original.toJson());

      expect(restored.id, 'lines');
      expect(restored.isSection, isTrue);
      expect(restored.rowSource, 'invoice.lines');
      expect(restored.columns.length, 2);
      expect(restored.columns[1].width, 80);
      expect(restored.columns[1].align, 'right');
      expect(restored.zebra, isTrue);
      expect(restored.maxRows, 12);
    });

    test('CanvasElement.fromJson dispatches type "table"', () {
      final e = CanvasElement.fromJson({
        'id': 't',
        'type': 'table',
        'rowSource': 'items',
      });
      expect(e, isA<TableElement>());
      expect((e as TableElement).rowSource, 'items');
    });

    test('elementsFromJson accepts a table alongside other elements', () {
      final els = elementsFromJson(
        '[{"id":"a","type":"text","content":"hi"},'
        '{"id":"b","type":"table","rowSource":"items"}]',
      );
      expect(els.length, 2);
      expect(els[1], isA<TableElement>());
    });
  });
}
