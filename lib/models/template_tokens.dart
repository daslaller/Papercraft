/// Which `{{tokens}}` a template actually references.
///
/// A template is a contract with its host: "give me these fields and I will
/// draw a document." Until now that contract was implicit — the only way to
/// discover it was to render and see what came out blank, which is a terrible
/// way to find out that an insurance form needs a claim number nobody has.
///
/// [tokensIn] makes it explicit, so a host can compare the template's needs
/// against the record it is about to print with and do something useful about
/// the difference — ask the user, warn, or refuse.
library;

import 'element_model.dart';
import 'table_element.dart';

final RegExp _token = RegExp(r'\{\{([^}]+)\}\}');

/// Every token path referenced anywhere in [elements], in first-appearance
/// order.
///
/// Walks the whole tree — nested containers, table column keys *and* their
/// header labels, QR and barcode content, image sources — because a token
/// hiding in a table cell is exactly as missing as one in a heading.
///
/// Filters are stripped (`{{customer.name|uppercase}}` yields
/// `customer.name`), and `computed:` references are skipped: those are derived
/// from other tokens by [ComputedField] rather than supplied by the host.
List<String> tokensIn(List<CanvasElement> elements) {
  final found = <String>{};
  final ordered = <String>[];

  void add(String? text) {
    if (text == null || text.isEmpty) return;
    for (final match in _token.allMatches(text)) {
      final path = match.group(1)!.trim().split('|').first.trim();
      if (path.isEmpty || path.startsWith('computed:')) continue;
      if (found.add(path)) ordered.add(path);
    }
  }

  void walk(CanvasElement e) {
    switch (e) {
      case TextElement t:
        add(t.content);
      case QrElement q:
        add(q.content);
      case BarcodeElement b:
        add(b.content);
      case ImageElement i:
        add(i.src);
      case TableElement t:
        for (final c in t.columns) {
          add(c.label);
          // A column key is a plain field name on the row *unless* it is a
          // token expression, in which case it resolves against the document.
          if (c.key.contains('{{')) add(c.key);
        }
      case ContainerElement c:
        c.children.forEach(walk);
      default:
        break;
    }
  }

  elements.forEach(walk);
  return ordered;
}

/// The tokens [elements] needs that [record] has no entry for at all.
///
/// **Absent is not the same as empty, and the difference is the whole point.**
/// A host that knows about a field and has nothing to put in it should send
/// `''` — an invoice with no notes is a complete invoice. A key that is
/// missing *entirely* means nothing in the system supplies that field, which
/// is a different situation and the one worth surfacing.
///
/// So this deliberately does not report `{{invoice.notes}}` when the record
/// carries `'invoice.notes': ''`, and does report `{{insurance.claim_number}}`
/// when no such key exists anywhere.
///
/// [ignore] drops paths the host resolves by other means.
List<String> missingTokens(
  List<CanvasElement> elements,
  Map<String, dynamic>? record, {
  Set<String> ignore = const {},
}) {
  final present = record?.keys.toSet() ?? const <String>{};
  return [
    for (final path in tokensIn(elements))
      if (!present.contains(path) && !ignore.contains(path)) path,
  ];
}
