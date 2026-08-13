import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/papercraft.dart';

void main() {
  group('determinism', () {
    test('compiling the same spec twice is byte-identical', () {
      // generateId() is `el_<millis>_<n>`, so if the compiler used it a
      // screenshot or golden of a default template would churn on every run.
      final spec = col([
        row([text('{{company.name}}', flex: 3), text('INVOICE', flex: 1)]),
        rule(),
        table('invoice.lines',
            columns: const [TableColumn(key: 'description')]),
      ]);

      final a = elementsToJson(compileTemplate(spec, idPrefix: 'inv'));
      final b = elementsToJson(compileTemplate(spec, idPrefix: 'inv'));

      expect(a, b);
    });

    test('ids are namespaced by idPrefix', () {
      final els = compileTemplate(col([text('a'), text('b')]), idPrefix: 'x');
      final json = elementsToJson(els);
      expect(json, contains('x_'));
      expect(json, isNot(contains('el_')));
    });
  });

  group('flow-only by construction', () {
    test('nothing ever gets absolute coordinates', () {
      final els = compileTemplate(
        col([
          row([text('a'), qr('{{ticket.id}}')]),
          table('lines'),
          rule(),
          spacer(height: 12),
        ]),
        idPrefix: 't',
      );

      expect(() => assertFlowOnly(els), returnsNormally);
    });

    test('a top-level text is wrapped so it still flows', () {
      // text/shape/qr hardcode isSection = false, so an unwrapped one would be
      // dropped by both renderers' `where((e) => e.isSection)`.
      final els = compileTemplate(col([text('heading')]), idPrefix: 't');

      expect(els.single.isSection, isTrue);
      expect(els.single, isA<ContainerElement>());
      expect((els.single as ContainerElement).children.single,
          isA<TextElement>());
    });

    test('a top-level table marks itself rather than being wrapped', () {
      final els = compileTemplate(col([table('lines')]), idPrefix: 't');

      expect(els.single, isA<TableElement>());
      expect(els.single.isSection, isTrue);
    });

    test('assertFlowOnly rejects a hand-assembled absolute element', () {
      expect(
        () => assertFlowOnly(const [TextElement(id: 'a', x: 10, y: 10)]),
        throwsStateError,
      );
    });
  });

  group('compilation', () {
    test('rows and columns nest with the right types', () {
      final els = compileTemplate(
        col([
          row([text('l'), text('r')]),
        ]),
        idPrefix: 't',
      );

      final section = els.single as ContainerElement;
      expect(section.type, 'row');
      expect(section.children.length, 2);
      expect(section.children.every((c) => c is TextElement), isTrue);
    });

    test('rows centre and columns stretch by default', () {
      // A label beside a value reads wrong top-aligned; a column must stretch
      // so a right-aligned total has the full width to align against.
      final r = compileTemplate(col([
            row([text('a')])
          ]), idPrefix: 't').single as ContainerElement;
      final c = compileTemplate(col([
            col([text('a')])
          ]), idPrefix: 't').single as ContainerElement;

      expect(r.alignItems, 'center');
      expect(c.alignItems, 'stretch');
    });

    test('kv hugs its label and lets the value take the rest', () {
      final section =
          compileTemplate(col([kv('Total', '100 kr')]), idPrefix: 't').single
              as ContainerElement;

      final k = section.children[0] as TextElement;
      final v = section.children[1] as TextElement;

      // Intrinsic label, flexed value — the whole point of allowing a null flex.
      expect(k.flex, isNull);
      expect(v.flex, 1);
      expect(v.textAlign, 'right');
    });

    test('label uppercases its caption', () {
      final section =
          compileTemplate(col([label('bill to')]), idPrefix: 't').single
              as ContainerElement;
      expect((section.children.single as TextElement).content, 'BILL TO');
    });

    test('table columns survive compilation', () {
      final els = compileTemplate(
        col([
          table('invoice.lines', columns: const [
            TableColumn(key: 'description', label: 'Description', flex: 4),
            TableColumn(key: 'amount', label: 'Amount', align: 'right'),
          ], zebra: true),
        ]),
        idPrefix: 't',
      );

      final t = els.single as TableElement;
      expect(t.rowSource, 'invoice.lines');
      expect(t.columns.map((c) => c.key), ['description', 'amount']);
      expect(t.columns[1].align, 'right');
      expect(t.zebra, isTrue);
    });

    test('an unknown node fails loudly rather than rendering nothing', () {
      expect(
        () => compileTemplate(col([
          {'wat': 1}
        ]), idPrefix: 't'),
        throwsArgumentError,
      );
    });
  });

  group('the two surfaces agree', () {
    test('JSON and the Dart builders compile to the same elements', () {
      final fromDart = compileTemplate(
        col([
          row([text('{{company.name}}', size: 20, weight: 'bold', flex: 3)]),
        ]),
        idPrefix: 't',
      );

      final fromJson = compileTemplateJson(
        '{"col":[{"row":[{"text":"{{company.name}}","size":20,'
        '"weight":"bold","flex":3}]}]}',
        idPrefix: 't',
      );

      expect(elementsToJson(fromDart), elementsToJson(fromJson));
    });

    test('compiled output round-trips through storage JSON', () {
      // The editor must be able to open a compiled default and edit it like
      // anything else, which means the element JSON has to survive a save/load.
      final els = compileTemplate(
        col([
          row([text('a', flex: 1), qr('{{ticket.id}}', size: 48)]),
          table('lines', columns: const [TableColumn(key: 'x')]),
        ]),
        idPrefix: 't',
      );

      final restored = elementsFromJson(elementsToJson(els));

      expect(elementsToJson(restored), elementsToJson(els));
    });
  });

  group('it actually prints', () {
    test('a DSL-authored document produces a PDF', () async {
      final els = compileTemplate(
        col([
          row([
            text('{{company.name}}', size: 18, weight: 'bold', flex: 3),
            text('INVOICE', size: 18, textAlign: 'right', flex: 2),
          ]),
          rule(),
          table('invoice.lines', columns: const [
            TableColumn(key: 'description', label: 'Description', flex: 4),
            TableColumn(key: 'amount', label: 'Amount', align: 'right'),
          ]),
          kv('Total', '{{invoice.total}}', bold: true),
        ]),
        idPrefix: 'invoice',
      );

      final bytes = await PrintService.buildPdf(
        template: Template(
          id: 't',
          name: 'Invoice',
          docType: 'document',
          canvasSize: 'A4',
          canvasWidthMm: 210,
          canvasHeightMm: 297,
          backgroundColor: '#ffffff',
          elements: '[]',
          sectionLayoutEnabled: true,
          ownerId: 'o',
          createdDate: DateTime(2026),
          updatedDate: DateTime(2026),
        ),
        elements: els,
        record: {
          'company.name': 'Mobilx',
          'invoice.total': '1 234,00 kr',
          'invoice.lines': [
            {'description': 'Screen replacement', 'amount': '1 000,00'},
            {'description': 'Labour', 'amount': '234,00'},
          ],
        },
      );

      expect(bytes.length, greaterThan(1000));
    });
  });
}
