import 'package:papercraft/models/template_model.dart';
import 'package:papercraft/services/printer_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrinterProvider.resolveFromList', () {
    final printers = [
      PapercraftPrinter.external(id: 'ext-1', name: 'Cloud Label'),
      const PapercraftPrinter(id: 'local-hp', name: 'HP LaserJet', isLocal: true),
    ];

    test('prefers printerId over name', () {
      final t = Template(
        id: 't1',
        name: 'Ticket',
        docType: 'label',
        ownerId: 'u',
        printerId: 'ext-1',
        printerName: 'HP LaserJet',
        createdDate: DateTime(2026),
        updatedDate: DateTime(2026),
      );
      final resolved = PrinterProvider.resolveFromList(t, printers);
      expect(resolved?.id, 'ext-1');
    });

    test('falls back to printerName', () {
      final t = Template(
        id: 't1',
        name: 'Ticket',
        docType: 'label',
        ownerId: 'u',
        printerName: 'HP LaserJet',
        createdDate: DateTime(2026),
        updatedDate: DateTime(2026),
      );
      final resolved = PrinterProvider.resolveFromList(t, printers);
      expect(resolved?.id, 'local-hp');
    });

    test('returns null when unavailable', () {
      final t = Template(
        id: 't1',
        name: 'Ticket',
        docType: 'label',
        ownerId: 'u',
        printerName: 'Missing Printer',
        createdDate: DateTime(2026),
        updatedDate: DateTime(2026),
      );
      expect(PrinterProvider.resolveFromList(t, printers), isNull);
    });
  });
}
