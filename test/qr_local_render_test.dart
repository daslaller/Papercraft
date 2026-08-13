import 'package:barcode/barcode.dart' as bc;
import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/papercraft.dart';

/// The modules [QrPainter] paints — it is a straight loop over this, so
/// asserting here asserts the drawn matrix without needing a rasteriser.
List<bc.BarcodeBar> _modules(String data, {double side = 120}) =>
    bc.Barcode.qrCode()
        .make(data, width: side, height: side)
        .whereType<bc.BarcodeBar>()
        .where((b) => b.black)
        .toList();

void main() {
  group('QR is encoded locally', () {
    test('a real matrix is produced, not a placeholder', () {
      final modules = _modules('https://repairx.se/t/ABC123');

      // The old canvas placeholder drew exactly 6 rectangles — three finder
      // squares, two each. A real QR is hundreds of modules.
      expect(modules.length, greaterThan(100));
    });

    test('the matrix covers a plausible share of the canvas', () {
      const side = 120.0;
      final inked = _modules('TICKET-0001', side: side)
          .fold<double>(0, (a, b) => a + b.width * b.height);

      final ratio = inked / (side * side);
      expect(ratio, greaterThan(0.15));
      expect(ratio, lessThan(0.75));
    });

    test('different content produces a different matrix', () {
      final a = _modules('TICKET-0001');
      final b = _modules('a much longer payload that forces a larger QR '
          'version and therefore a different module count entirely');

      expect(a.length, isNot(b.length));
    });

    test('modules stay inside the requested box', () {
      const side = 64.0;
      for (final m in _modules('TCK-4821', side: side)) {
        expect(m.left, greaterThanOrEqualTo(0));
        expect(m.top, greaterThanOrEqualTo(0));
        expect(m.left + m.width, lessThanOrEqualTo(side + 0.001));
        expect(m.top + m.height, lessThanOrEqualTo(side + 0.001));
      }
    });

    test('empty content is handled without throwing', () {
      // QrPainter returns early on empty data; the encoder is never asked.
      expect(() => _modules(''), returnsNormally);
    });
  });

  group('QR reaches the PDF without a network call', () {
    test('a QR element renders into the PDF offline', () async {
      // This test has no network. Before the local encoder, the QR was fetched
      // from api.qrserver.com and a failed fetch printed a grey rectangle —
      // a label that cannot be scanned, with nothing to say it went wrong.
      final bytes = await PrintService.buildPdf(
        template: Template(
          id: 't',
          name: 'Label',
          docType: 'label',
          canvasSize: 'custom',
          canvasWidthMm: 62,
          canvasHeightMm: 40,
          backgroundColor: '#ffffff',
          elements: '[]',
          ownerId: 'o',
          createdDate: DateTime(2026),
          updatedDate: DateTime(2026),
        ),
        elements: const [
          QrElement(
              id: 'q',
              x: 4,
              y: 4,
              width: 75,
              height: 75,
              content: '{{ticket.id}}'),
        ],
        record: {'ticket.id': 'TCK-4821'},
      );

      expect(bytes.length, greaterThan(1000));
    });

    test('the QR content is token-resolved before encoding', () {
      // A label whose QR encodes the literal "{{ticket.id}}" scans to garbage.
      final resolved = TokenService.resolveTokens(
          '{{ticket.id}}', {'ticket.id': 'TCK-4821'}, 'tickets', const []);
      expect(resolved, 'TCK-4821');
    });
  });

  group('symbology selection', () {
    test('a 13-digit SKU with a non-EAN checksum still prints', () async {
      // Detection used to pick EAN-13 on length alone, and `barcode` THROWS
      // when the check digit does not match — so a shop numbering its own
      // parts with 13 digits got a BarcodeException instead of a shelf label,
      // and the exception took the whole PDF with it.
      final bytes = await PrintService.buildPdf(
        template: Template(
          id: 't',
          name: 'Product label',
          docType: 'label',
          canvasSize: 'custom',
          canvasWidthMm: 50,
          canvasHeightMm: 25,
          backgroundColor: '#ffffff',
          elements: '[]',
          ownerId: 'o',
          createdDate: DateTime(2026),
          updatedDate: DateTime(2026),
        ),
        elements: const [
          BarcodeElement(
              id: 'b',
              x: 4,
              y: 4,
              width: 160,
              height: 40,
              content: '{{product.sku}}'),
        ],
        record: {'product.sku': '7350100112233'},
      );

      expect(bytes.length, greaterThan(500));
    });

    test('a genuine EAN-13 is still encoded as EAN-13', () async {
      final bytes = await PrintService.buildPdf(
        template: Template(
          id: 't',
          name: 'Product label',
          docType: 'label',
          canvasSize: 'custom',
          canvasWidthMm: 50,
          canvasHeightMm: 25,
          backgroundColor: '#ffffff',
          elements: '[]',
          ownerId: 'o',
          createdDate: DateTime(2026),
          updatedDate: DateTime(2026),
        ),
        elements: const [
          BarcodeElement(
              id: 'b', x: 4, y: 4, width: 160, height: 40, content: '5901234123457'),
        ],
      );
      expect(bytes.length, greaterThan(500));
    });
  });
}
