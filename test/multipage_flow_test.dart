import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/papercraft.dart';

/// Counts `/Type /Page` objects in the raw PDF. Crude, but it is the one thing
/// that matters here and it needs no rasteriser.
int _pageCount(List<int> bytes) =>
    RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(bytes)).length;

Template _a4({bool sectionLayout = true}) => Template(
      id: 't',
      name: 'T',
      docType: 'document',
      canvasSize: 'A4',
      canvasWidthMm: 210,
      canvasHeightMm: 297,
      backgroundColor: '#ffffff',
      elements: '[]',
      sectionLayoutEnabled: sectionLayout,
      ownerId: 'o',
      createdDate: DateTime(2026),
      updatedDate: DateTime(2026),
    );

List<Map<String, String>> _lines(int n) => [
      for (var i = 0; i < n; i++)
        {'description': 'Line item $i', 'qty': '1', 'amount': '100,00'},
    ];

const _columns = [
  TableColumn(key: 'description', label: 'Description', flex: 4),
  TableColumn(key: 'qty', label: 'Qty', align: 'right'),
  TableColumn(key: 'amount', label: 'Amount', flex: 2, align: 'right'),
];

void main() {
  group('isFlowOnly', () {
    test('true when every element is a section', () {
      expect(
        isFlowOnly([
          ContainerElement(id: 'a', type: 'col', isSection: true),
          const TableElement(id: 'b', isSection: true),
        ]),
        isTrue,
      );
    });

    test('false when anything is absolutely positioned', () {
      expect(
        isFlowOnly([
          ContainerElement(id: 'a', type: 'col', isSection: true),
          const TextElement(id: 'b', x: 10, y: 10),
        ]),
        isFalse,
      );
    });

    test('false for an empty template', () => expect(isFlowOnly([]), isFalse));
  });

  group('pagination', () {
    test('a flow-only template with a long table spills onto more pages', () async {
      final bytes = await PrintService.buildPdf(
        template: _a4(),
        elements: const [
          TableElement(
              id: 'lines',
              isSection: true,
              rowSource: 'invoice.lines',
              columns: _columns),
        ],
        record: {'invoice.lines': _lines(120)},
      );

      // 120 rows cannot fit one A4 page. Before MultiPage they were simply
      // clipped away — the document looked complete and was not.
      expect(_pageCount(bytes), greaterThan(1));
    });

    test('a short flow-only template stays on one page', () async {
      final bytes = await PrintService.buildPdf(
        template: _a4(),
        elements: const [
          TableElement(
              id: 'lines',
              isSection: true,
              rowSource: 'invoice.lines',
              columns: _columns),
        ],
        record: {'invoice.lines': _lines(3)},
      );

      expect(_pageCount(bytes), 1);
    });

    test('an absolutely positioned template keeps the single-page path', () async {
      // Backward compatibility: every template authored before this change has
      // absolute coordinates, and a pw.Positioned has no meaning once content
      // reflows, so those must never be handed to MultiPage.
      final bytes = await PrintService.buildPdf(
        template: _a4(sectionLayout: false),
        elements: const [
          TableElement(
              id: 'lines',
              x: 40,
              y: 40,
              width: 500,
              rowSource: 'invoice.lines',
              columns: _columns),
        ],
        record: {'invoice.lines': _lines(120)},
      );

      expect(_pageCount(bytes), 1);
    });

    test('paginate: false forces one page even when flow-only', () async {
      final bytes = await PrintService.buildPdf(
        template: _a4(),
        elements: const [
          TableElement(
              id: 'lines',
              isSection: true,
              rowSource: 'invoice.lines',
              columns: _columns),
        ],
        record: {'invoice.lines': _lines(120)},
        paginate: false,
      );

      expect(_pageCount(bytes), 1);
    });
  });

  group('rendering does not throw', () {
    test('a flowing table beside flowing containers', () async {
      // The old .cast<ContainerElement>() on the section list threw here.
      final bytes = await PrintService.buildPdf(
        template: _a4(),
        elements: [
          ContainerElement(id: 'head', type: 'row', isSection: true, children: [
            const TextElement(id: 't1', content: '{{company.name}}', flex: 3),
            const TextElement(id: 't2', content: 'INVOICE', flex: 1),
          ]),
          const TableElement(
              id: 'lines',
              isSection: true,
              rowSource: 'invoice.lines',
              columns: _columns),
        ],
        record: {'company.name': 'Mobilx', 'invoice.lines': _lines(5)},
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('an empty bound list renders the empty text, not a crash', () async {
      final bytes = await PrintService.buildPdf(
        template: _a4(),
        elements: const [
          TableElement(
              id: 'lines',
              isSection: true,
              rowSource: 'invoice.lines',
              columns: _columns,
              emptyText: 'Nothing to invoice.'),
        ],
        record: const {'invoice.lines': []},
      );

      expect(bytes.length, greaterThan(500));
    });
  });
}
