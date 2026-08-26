import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/papercraft.dart';

/// The table node exactly as the RepairX invoice JSON ships it — absolute
/// coordinates, `rowSource`, double flex, derived height. Loading this without
/// throwing, and resolving four sample rows into six aligned columns, is the
/// contract the engine has to keep.
const _repairxTableJson = '''
{
  "id": "lines",
  "type": "table",
  "x": 40, "y": 296, "width": 714,
  "rotation": 0, "opacity": 1, "zIndex": 23,
  "rowSource": "invoice.lines",
  "columns": [
    { "key": "description", "label": "Description", "flex": 6,   "align": "left" },
    { "key": "sku",         "label": "SKU",         "flex": 2,   "align": "left" },
    { "key": "qty",         "label": "Qty",         "flex": 1,   "align": "right" },
    { "key": "unit_price",  "label": "Unit",        "flex": 1.6, "align": "right" },
    { "key": "vat_rate",    "label": "VAT %",       "flex": 1.1, "align": "right" },
    { "key": "amount",      "label": "Amount",      "flex": 1.8, "align": "right" }
  ],
  "headerHeight": 24, "rowHeight": 22, "maxRows": 14,
  "fontSize": 9, "fontFamily": "Inter", "color": "#0F172A",
  "headerFontSize": 8, "headerColor": "#64748B", "headerBackground": "#F1F5F9",
  "gridColor": "#E2E8F0", "gridWidth": 0.5,
  "zebra": false, "zebraColor": "#F8FAFC", "cellPaddingX": 6
}
''';

void main() {
  group('RepairX line-items JSON', () {
    test('CanvasElement.fromJson accepts the shipped table object', () {
      final e = CanvasElement.fromJson(
        jsonDecode(_repairxTableJson) as Map<String, dynamic>,
      );
      expect(e, isA<TableElement>());
      final t = e as TableElement;
      expect(t.rowSource, 'invoice.lines');
      expect(t.columns.map((c) => c.key), [
        'description',
        'sku',
        'qty',
        'unit_price',
        'vat_rate',
        'amount',
      ]);
      expect(t.columns[3].flex, 1.6);
      expect(t.columns[5].align, 'right');
      expect(t.headerHeight, 24);
      expect(t.rowHeight, 22);
      expect(t.headerColor, '#64748B');
      expect(t.headerBackground, '#F1F5F9');
      expect(t.gridWidth, 0.5);
      expect(t.cellPaddingX, 6);
    });

    test('resolveTable fills cells from invoice.lines', () {
      final t = TableElement.fromJson(
        jsonDecode(_repairxTableJson) as Map<String, dynamic>,
      );
      final resolved = resolveTable(t, kRepairXSampleRecord);
      expect(resolved.cells.length, 4);
      expect(resolved.cells.first, [
        'Display assembly replacement — iPhone 14 Pro',
        'SCR-IP14P-OEM',
        '1',
        '2 592.00',
        '25',
        '2 592.00',
      ]);
      expect(resolved.columns[3].flex, 1.6);
    });

    test('a DSL spec can embed the raw table JSON and still flow', () {
      final tableJson =
          jsonDecode(_repairxTableJson) as Map<String, dynamic>;
      final els = compileTemplate(col([
        text('INVOICE', size: 24, weight: 'bold'),
        tableJson,
      ]), idPrefix: 'inv');

      expect(() => assertFlowOnly(els), returnsNormally);
      final t = els.whereType<TableElement>().single;
      expect(t.rowSource, 'invoice.lines');
      expect(t.isSection, isTrue);
      expect(t.x, isNull);
      expect(t.y, isNull);
      expect(t.paddingX, 40);
      expect(t.headerFontSize, 8);
      expect(t.cellPaddingX, 6);
    });

    test('DSL table{} passes through the visual contract', () {
      final t = compileTemplate(
        col([
          table('invoice.lines',
              columns: kRepairXLineColumns,
              headerHeight: 24,
              rowHeight: 22,
              headerFontSize: 8,
              headerColor: kMuted,
              headerBackground: kTint,
              gridColor: kHairline,
              gridWidth: 0.5,
              cellPaddingX: 6,
              color: kInk),
        ]),
        idPrefix: 't',
      ).single as TableElement;

      expect(t.rowSource, 'invoice.lines');
      expect(t.headerHeight, 24);
      expect(t.rowHeight, 22);
      expect(t.headerFontSize, 8);
      expect(t.headerColor, kMuted);
      expect(t.headerBackground, kTint);
      expect(t.gridWidth, 0.5);
      expect(t.columns[3].flex, 1.6);
      expect(t.paddingX, 0);
    });

    test('DSL table padX becomes TableElement.paddingX', () {
      final t = compileTemplate(
        col([
          table('invoice.lines', padX: 40, columns: kRepairXLineColumns),
        ]),
        idPrefix: 't',
      ).single as TableElement;
      expect(t.paddingX, 40);
      expect(t.isSection, isTrue);
    });
  });

  group('RepairX row/col defaults', () {
    test('seven templates, each with a docRole', () {
      expect(kRepairXDefaultTemplates.length, 7);
      expect(
        kRepairXDefaultTemplates.map((d) => d.docRole).toSet(),
        {
          'invoice',
          'estimate',
          'insurance',
          'intake',
          'ticket_label',
          'purchase_label',
          'product_label',
        },
      );
    });

    test('every default compiles to flow-only elements', () {
      for (final def in kRepairXDefaultTemplates) {
        expect(() => def.elements, returnsNormally, reason: def.id);
        expect(isFlowOnly(def.elements), isTrue, reason: def.id);
        expect(() => assertFlowOnly(def.elements), returnsNormally,
            reason: def.id);
      }
    });

    test('compiling twice is byte-identical', () {
      for (final def in kRepairXDefaultTemplates) {
        expect(elementsToJson(def.elements), elementsToJson(def.elements),
            reason: def.id);
      }
    });

    test('invoice and estimate bind line-item tables', () {
      TableElement tableOf(String role) {
        final def =
            kRepairXDefaultTemplates.firstWhere((d) => d.docRole == role);
        TableElement? find(CanvasElement e) {
          if (e is TableElement) return e;
          if (e is ContainerElement) {
            for (final c in e.children) {
              final hit = find(c);
              if (hit != null) return hit;
            }
          }
          return null;
        }

        for (final e in def.elements) {
          final hit = find(e);
          if (hit != null) return hit;
        }
        throw StateError('no table in $role');
      }

      expect(tableOf('invoice').rowSource, 'invoice.lines');
      expect(tableOf('invoice').paddingX, 40);
      expect(tableOf('estimate').rowSource, 'estimate.lines');
      expect(tableOf('insurance').rowSource, 'estimate.lines');
    });

    test('missingTokens reports the line-item list key', () {
      final def = kRepairXDefaultTemplates
          .firstWhere((d) => d.docRole == 'invoice');
      expect(listSourcesIn(def.elements), ['invoice.lines']);
      expect(
        missingTokens(def.elements, {'company.name': 'x'}),
        contains('invoice.lines'),
      );
      expect(
        missingTokens(def.elements, {
          ...kRepairXSampleRecord,
        }),
        isEmpty,
      );
    });

    test('compiled output round-trips through storage JSON', () {
      for (final def in kRepairXDefaultTemplates) {
        final restored = elementsFromJson(def.elementsJson);
        expect(elementsToJson(restored), def.elementsJson, reason: def.id);
      }
    });
  });

  group('it actually prints', () {
    Template templateOf(DefaultPrintTemplate def) => def.toTemplate(
          ownerId: 'o',
          now: DateTime(2026),
        );

    test('every default produces a PDF with the sample record', () async {
      for (final def in kRepairXDefaultTemplates) {
        final bytes = await PrintService.buildPdf(
          template: templateOf(def),
          elements: def.elements,
          record: kRepairXSampleRecord,
          entityName: 'tickets',
        );
        expect(bytes.length, greaterThan(1000), reason: def.id);
      }
    });

    test('invoice PDF is a real document with a line-items table', () async {
      final def = kRepairXDefaultTemplates
          .firstWhere((d) => d.docRole == 'invoice');
      final table = def.elements.whereType<TableElement>().first;
      final resolved = resolveTable(table, kRepairXSampleRecord);
      expect(resolved.cells.length, 4);
      expect(resolved.cells.first.first, contains('Display assembly'));

      final bytes = await PrintService.buildPdf(
        template: templateOf(def),
        elements: def.elements,
        record: kRepairXSampleRecord,
      );
      expect(bytes.length, greaterThan(2000));
      expect(bytes[0], 0x25); // %PDF
      expect(bytes[1], 0x50);
    });

    test('a long invoice paginates instead of clipping lines', () async {
      final def = kRepairXDefaultTemplates
          .firstWhere((d) => d.docRole == 'invoice');
      final record = Map<String, dynamic>.from(kRepairXSampleRecord);
      record['invoice.lines'] = [
        for (var i = 0; i < 80; i++)
          {
            'description': 'Spare part $i',
            'sku': 'SKU-$i',
            'qty': '1',
            'unit_price': '10.00',
            'vat_rate': '25',
            'amount': '10.00',
          },
      ];
      final bytes = await PrintService.buildPdf(
        template: templateOf(def),
        elements: def.elements,
        record: record,
      );
      final pages =
          RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes));
      expect(pages.length, greaterThan(1));
    });
  });
}
