import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/papercraft.dart';

void main() {
  group('tokensIn', () {
    test('finds tokens in text, qr, barcode and image', () {
      final tokens = tokensIn(const [
        TextElement(id: 'a', content: 'Hello {{customer.name}}'),
        QrElement(id: 'b', content: '{{ticket.id}}'),
        BarcodeElement(id: 'c', content: '{{product.sku}}'),
        ImageElement(id: 'd', src: '{{company.logo_url}}'),
      ]);

      expect(tokens, [
        'customer.name',
        'ticket.id',
        'product.sku',
        'company.logo_url',
      ]);
    });

    test('descends into nested containers', () {
      final tokens = tokensIn([
        ContainerElement(id: 'root', type: 'col', children: [
          ContainerElement(id: 'r', type: 'row', children: const [
            TextElement(id: 't', content: '{{company.name}}'),
          ]),
        ]),
      ]);

      expect(tokens, ['company.name']);
    });

    test('finds tokens in table headers and token columns', () {
      // A token hiding in a table is exactly as missing as one in a heading.
      final tokens = tokensIn(const [
        TableElement(id: 'x', rowSource: 'lines', columns: [
          TableColumn(key: 'description', label: 'Description'),
          TableColumn(key: 'amount', label: 'Amount ({{invoice.currency}})'),
          TableColumn(key: '{{qty}} x {{invoice.unit_label}}'),
        ]),
      ]);

      expect(tokens, contains('invoice.currency'));
      expect(tokens, contains('invoice.unit_label'));
      // A plain row-field key is not a document token.
      expect(tokens, isNot(contains('description')));
    });

    test('strips filters and skips computed references', () {
      final tokens = tokensIn(const [
        TextElement(id: 'a', content: '{{customer.name|uppercase}}'),
        TextElement(id: 'b', content: '{{computed:line_total}}'),
      ]);

      expect(tokens, ['customer.name']);
    });

    test('de-duplicates but keeps first-appearance order', () {
      final tokens = tokensIn(const [
        TextElement(id: 'a', content: '{{b.two}} {{a.one}}'),
        TextElement(id: 'b', content: '{{a.one}}'),
      ]);

      expect(tokens, ['b.two', 'a.one']);
    });

    test('returns nothing for a template with no tokens', () {
      expect(tokensIn(const [TextElement(id: 'a', content: 'Static')]), isEmpty);
    });
  });

  group('missingTokens', () {
    const elements = [
      TextElement(id: 'a', content: '{{customer.name}}'),
      TextElement(id: 'b', content: '{{invoice.notes}}'),
      TextElement(id: 'c', content: '{{insurance.claim_number}}'),
    ];

    test('an EMPTY value is not missing — the host knows the field', () {
      // An invoice with no notes is a complete invoice. Reporting it would
      // make the host prompt for something deliberately blank.
      final missing = missingTokens(elements, {
        'customer.name': 'Annika',
        'invoice.notes': '',
        'insurance.claim_number': '',
      });

      expect(missing, isEmpty);
    });

    test('an ABSENT key is missing — nothing supplies that field', () {
      final missing = missingTokens(elements, {
        'customer.name': 'Annika',
        'invoice.notes': '',
      });

      expect(missing, ['insurance.claim_number']);
    });

    test('a null record makes every token missing', () {
      expect(missingTokens(elements, null).length, 3);
    });

    test('ignore drops paths the host resolves another way', () {
      final missing = missingTokens(
        elements,
        const {},
        ignore: {'customer.name', 'invoice.notes'},
      );

      expect(missing, ['insurance.claim_number']);
    });
  });
}
