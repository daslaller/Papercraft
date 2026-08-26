/// RepairX default print templates, authored as row/col DSL.
///
/// The designs started life as absolutely positioned element JSON (x/y at
/// 3.78 px/mm). That format cannot paginate, and a long invoice silently
/// clipped. These specs compile through [compileTemplate] into the same
/// element list the editor and both painters already consume, but every node
/// flows — so a table of line items is a real [TableElement] bound to
/// `invoice.lines` / `estimate.lines`, not a pre-joined multiline string.
///
/// Compiling is the point: the host stores elements, the studio edits
/// elements, print paints elements. The DSL is an authoring tool, not a
/// second runtime format.
library;

import '../models/element_model.dart';
import '../models/table_element.dart';
import '../models/template_dsl.dart';
import '../models/template_model.dart';

/// The six priced-work columns every invoice / estimate / insurance table uses.
const kRepairXLineColumns = [
  TableColumn(key: 'description', label: 'Description', flex: 6),
  TableColumn(key: 'sku', label: 'SKU', flex: 2),
  TableColumn(key: 'qty', label: 'Qty', flex: 1, align: 'right'),
  TableColumn(key: 'unit_price', label: 'Unit', flex: 1.6, align: 'right'),
  TableColumn(key: 'vat_rate', label: 'VAT %', flex: 1.1, align: 'right'),
  TableColumn(key: 'amount', label: 'Amount', flex: 1.8, align: 'right'),
];

/// A seedable Papercraft template definition.
class DefaultPrintTemplate {
  final String id;
  final String name;
  final String docType;
  final String docRole;
  final String canvasSize;
  final double widthMm;
  final double heightMm;
  final Map<String, dynamic> spec;

  const DefaultPrintTemplate({
    required this.id,
    required this.name,
    required this.docType,
    required this.docRole,
    required this.canvasSize,
    required this.widthMm,
    required this.heightMm,
    required this.spec,
  });

  /// Compiles [spec] to a flow-only element list. Deterministic ids.
  List<CanvasElement> get elements {
    final els = compileTemplate(spec, idPrefix: id);
    assertFlowOnly(els);
    return els;
  }

  String get elementsJson => elementsToJson(elements);

  Template toTemplate({required String ownerId, DateTime? now}) {
    final t = now ?? DateTime.now();
    return Template(
      id: id,
      name: name,
      docType: docType,
      docRole: docRole,
      canvasSize: canvasSize,
      canvasWidthMm: widthMm,
      canvasHeightMm: heightMm,
      backgroundColor: '#ffffff',
      elements: elementsJson,
      connectedEntity: 'tickets',
      sectionLayoutEnabled: true,
      isDefault: true,
      ownerId: ownerId,
      createdDate: t,
      updatedDate: t,
    );
  }
}

/// Sentinel accent baked into every layout. Swap it for the company's own
/// colour from `document_templates.accent_color` at seed time.
const String kSeedAccentColor = kAccent;

String withAccent(String elementsJson, String accentHex) =>
    accentHex.trim().isEmpty
        ? elementsJson
        : elementsJson.replaceAll(kSeedAccentColor, accentHex.trim());

/// All seven RepairX defaults, in the order a shop will meet them.
final kRepairXDefaultTemplates = <DefaultPrintTemplate>[
  DefaultPrintTemplate(
    id: 'repairx_default_invoice',
    name: 'Default Invoice',
    docType: 'document',
    docRole: 'invoice',
    canvasSize: 'A4',
    widthMm: 210,
    heightMm: 297,
    spec: _invoice,
  ),
  DefaultPrintTemplate(
    id: 'repairx_default_estimate',
    name: 'Default Estimate',
    docType: 'document',
    docRole: 'estimate',
    canvasSize: 'A4',
    widthMm: 210,
    heightMm: 297,
    spec: _estimate,
  ),
  DefaultPrintTemplate(
    id: 'repairx_default_insurance',
    name: 'Default Insurance Document',
    docType: 'document',
    docRole: 'insurance',
    canvasSize: 'A4',
    widthMm: 210,
    heightMm: 297,
    spec: _insurance,
  ),
  DefaultPrintTemplate(
    id: 'repairx_default_intake',
    name: 'Default Intake Form',
    docType: 'document',
    docRole: 'intake',
    canvasSize: 'A4',
    widthMm: 210,
    heightMm: 297,
    spec: _intake,
  ),
  DefaultPrintTemplate(
    id: 'repairx_default_ticket_label',
    name: 'Default Ticket Label',
    docType: 'label',
    docRole: 'ticket_label',
    canvasSize: 'custom',
    widthMm: 62,
    heightMm: 40,
    spec: _ticketLabel,
  ),
  DefaultPrintTemplate(
    id: 'repairx_default_purchase_label',
    name: 'Default Customer Purchase Label',
    docType: 'label',
    docRole: 'purchase_label',
    canvasSize: 'custom',
    widthMm: 62,
    heightMm: 40,
    spec: _purchaseLabel,
  ),
  DefaultPrintTemplate(
    id: 'repairx_default_product_label',
    name: 'Default Product Label',
    docType: 'label',
    docRole: 'product_label',
    canvasSize: 'custom',
    widthMm: 50,
    heightMm: 25,
    spec: _productLabel,
  ),
];

// ── Shared pieces ────────────────────────────────────────────────────────────

Map<String, dynamic> _gutter(List<Map<String, dynamic>> children,
        {double gap = 10, double padY = 0, double padX = 40}) =>
    col(children, padX: padX, padY: padY, gap: gap);

Map<String, dynamic> _letterhead(
  String title,
  List<(String, String)> metas, {
  String? subtitle,
}) =>
    row([
      col([
        image('{{company.logo_url}}', width: 110, height: 34),
        text('{{company.name}}', size: 13, weight: 'bold'),
        text('{{company.address}}\n{{company.phone}} · {{company.email}}',
            size: 8.5, color: kMuted, lineHeight: 1.45),
      ], gap: 4, flex: 3),
      col([
        text(title,
            size: 24, weight: 'bold', textAlign: 'right', tracking: 0.5),
        if (subtitle != null)
          text(subtitle, size: 8.5, color: kMuted, textAlign: 'right'),
        for (final m in metas) meta(m.$1, m.$2),
      ], gap: 2, flex: 2),
    ], align: 'start', gap: 16);

Map<String, dynamic> _lines(String data) => table(
      data,
      columns: kRepairXLineColumns,
      headerHeight: 24,
      rowHeight: 22,
      size: 9,
      headerFontSize: 8,
      headerColor: kMuted,
      headerBackground: kTint,
      gridColor: kHairline,
      gridWidth: 0.5,
      cellPaddingX: 6,
      padX: 40,
      color: kInk,
      fontFamily: 'Inter',
    );

Map<String, dynamic> _totals({
  required List<(String, String)> rows,
  required String boxLabel,
  required String boxValue,
}) =>
    col([
      for (final r in rows) kv(r.$1, r.$2),
      col([
        row([
          text(boxLabel.toUpperCase(),
              size: 8, weight: 'bold', color: kMuted, tracking: 0.8),
          text(boxValue, size: 16, weight: 'bold', textAlign: 'right', flex: 1),
        ], gap: 8),
      ], background: kTint, padding: 12, radius: 8),
    ], gap: 6, flex: 1);

Map<String, dynamic> _footer(String copy) => col([
      spacer(height: 16),
      rule(),
      text(copy, size: 8, color: kMuted, lineHeight: 1.5),
    ], gap: 8);

// ── Invoice ──────────────────────────────────────────────────────────────────

final _invoice = col([
  bar(),
  _gutter([
    _letterhead('INVOICE', [
      ('Invoice no', '{{invoice.number}}'),
      ('Date', '{{invoice.date}}'),
      ('Due date', '{{invoice.due_date}}'),
      ('Ticket', '#{{ticket.number}}'),
    ]),
  ], padY: 26, gap: 8),
  _gutter([rule()]),
  _gutter([
    row([
      field('Bill to', '{{customer.name}}',
          sub:
              '{{customer.address}}\n{{customer.email}} · {{customer.phone}}',
          flex: 1),
      field('Device', '{{device.name}}',
          sub:
              'Serial {{device.serial}} · IMEI {{device.imei}}\nStatus {{ticket.status}}',
          flex: 1),
    ], align: 'start', gap: 24),
    field('Reference', '{{invoice.reference}} — {{repair.description}}',
        size: 9, weight: 'normal'),
  ], padY: 16, gap: 12),
  // Top-level so pw.Table can span pages — wrapping it in a padded col
  // makes MultiPage treat the whole block as unsplittable.
  _lines('invoice.lines'),
  _gutter([
    row([
      col([
        label('Notes'),
        text('{{invoice.notes}}', size: 8.5, lineHeight: 1.5),
        spacer(height: 6),
        text('Payment terms: {{invoice.payment_terms}}',
            size: 8.5, color: kMuted),
      ], gap: 2, flex: 1),
      _totals(
        rows: [
          ('Subtotal', '{{invoice.subtotal}} {{invoice.currency}}'),
          ('VAT {{invoice.vat_rate}}%',
              '{{invoice.vat_total}} {{invoice.currency}}'),
          ('Paid', '{{invoice.paid_amount}} {{invoice.currency}}'),
        ],
        boxLabel: 'Amount due',
        boxValue: '{{invoice.amount_due}} {{invoice.currency}}',
      ),
    ], align: 'start', gap: 24),
  ], padY: 12),
  _gutter([
    _footer(
        '{{company.name}} · VAT {{company.vat_number}} · Org.nr {{company.org_number}} · {{company.website}}\nThank you for your business.'),
  ], padY: 8),
]);

// ── Estimate ─────────────────────────────────────────────────────────────────

final _estimate = col([
  bar(),
  _gutter([
    _letterhead('ESTIMATE', [
      ('Estimate no', '{{estimate.number}}'),
      ('Date', '{{estimate.date}}'),
      ('Valid until', '{{estimate.valid_until}}'),
      ('Ticket', '#{{ticket.number}}'),
    ]),
  ], padY: 26, gap: 8),
  _gutter([rule()]),
  _gutter([
    row([
      field('Prepared for', '{{customer.name}}',
          sub: '{{customer.email}} · {{customer.phone}}', flex: 1),
      field('Device', '{{device.name}}',
          sub: 'Serial {{device.serial}} · IMEI {{device.imei}}', flex: 1),
    ], align: 'start', gap: 24),
    field('Reported fault', '{{repair.description}}',
        size: 9, weight: 'normal'),
    field('Technician diagnosis', '{{repair.diagnosis}}',
        size: 9, weight: 'normal'),
  ], padY: 16, gap: 12),
  _lines('estimate.lines'),
  _gutter([
    row([
      col([
        text(
            'Estimate valid until {{estimate.valid_until}}. Parts availability and pricing may change after this date.',
            size: 8.5,
            color: kMuted,
            lineHeight: 1.5),
      ], gap: 2, flex: 1),
      _totals(
        rows: [
          ('Subtotal', '{{estimate.subtotal}} {{estimate.currency}}'),
          ('VAT {{estimate.vat_rate}}%',
              '{{estimate.vat_total}} {{estimate.currency}}'),
        ],
        boxLabel: 'Estimate total',
        boxValue: '{{estimate.total}} {{estimate.currency}}',
      ),
    ], align: 'start', gap: 24),
  ], padY: 12),
  _gutter([
    heading('Authorization'),
    text(
        'I authorize {{company.name}} to carry out the work described above, up to a total of {{estimate.total}} {{estimate.currency}} including VAT. Work exceeding this amount requires my renewed approval. {{estimate.approval_note}}',
        size: 8.5,
        lineHeight: 1.6),
    row([
      sig('Customer signature', flex: 2),
      sig('Date', flex: 1),
      sig('Prepared by {{repair.technician}}', flex: 1),
    ], align: 'start', gap: 16),
    _footer(
        '{{company.name}} · VAT {{company.vat_number}} · Org.nr {{company.org_number}} · {{company.website}}'),
  ], padY: 16, gap: 10),
]);

// ── Insurance ────────────────────────────────────────────────────────────────

final _insurance = col([
  bar(),
  _gutter([
    _letterhead(
      'INSURANCE',
      [
        ('Claim no', '{{insurance.claim_number}}'),
        ('Policy no', '{{insurance.policy_number}}'),
        ('Date', '{{ticket.date}}'),
        ('Ticket', '#{{ticket.number}}'),
      ],
      subtitle: 'Damage report · Cost estimate · Proof of repair',
    ),
  ], padY: 26, gap: 8),
  _gutter([rule()]),
  _gutter([
    heading('1 · Policy & claim'),
    row([
      field('Insurer', '{{insurance.insurer}}', size: 9.5, flex: 1),
      field('Adjuster / reference', '{{insurance.adjuster}}',
          size: 9.5, flex: 1),
      field('Deductible', '{{insurance.deductible}} {{invoice.currency}}',
          size: 9.5, flex: 1),
    ], align: 'start', gap: 16),
    row([
      field('Incident date', '{{insurance.incident_date}}',
          size: 9.5, flex: 1),
      field('Cause of damage', '{{insurance.cause}}', size: 9.5, flex: 2),
    ], align: 'start', gap: 16),
    heading('2 · Policyholder & device'),
    row([
      field('Policyholder', '{{customer.name}}',
          sub: '{{customer.email}} · {{customer.phone}}',
          size: 9.5,
          flex: 1),
      field('Device', '{{device.name}}',
          sub: 'Colour {{device.color}}', size: 9.5, flex: 1),
      field('Identifiers', 'Serial {{device.serial}}',
          sub: 'IMEI {{device.imei}}', size: 9.5, flex: 1),
    ], align: 'start', gap: 16),
    field('Condition on arrival',
        '{{device.condition}} · Accessories received: {{device.accessories}}',
        size: 9,
        weight: 'normal'),
    heading('3 · Damage report'),
    text('{{insurance.damage_report}}', size: 9, lineHeight: 1.6),
    heading('4 · Technician assessment'),
    text('{{insurance.assessment}}', size: 9, lineHeight: 1.6),
  ], padY: 16, gap: 12),
  _gutter([heading('5 · Cost estimate')], padY: 8),
  _lines('estimate.lines'),
  _gutter([
    col([
      kv('Estimated cost', '{{estimate.total}} {{invoice.currency}}'),
      kv('Deductible', '{{insurance.deductible}} {{invoice.currency}}'),
      kv('Approved amount',
          '{{insurance.approved_amount}} {{invoice.currency}}',
          bold: true),
    ], gap: 2),
    heading('6 · Work performed · Proof of repair'),
    row([
      field('Work carried out', '{{repair.work_performed}}',
          size: 9, weight: 'normal', flex: 3),
      field('Parts replaced', '{{repair.parts_replaced}}',
          size: 9, weight: 'normal', flex: 2),
    ], align: 'start', gap: 16),
    text(
        'Completed {{repair.completed_date}} · Warranty {{repair.warranty_months}} months · Technician {{repair.technician}}',
        size: 8.5,
        color: kMuted),
    heading('7 · Declaration'),
    text(
        '{{company.name}} confirms the information above is accurate and that the work described was carried out on the device identified in section 2.',
        size: 8,
        lineHeight: 1.6),
    row([
      sig('Technician signature', flex: 1),
      sig('Policyholder signature', flex: 1),
    ], align: 'start', gap: 24),
  ], padY: 16, gap: 12),
]);

// ── Intake ───────────────────────────────────────────────────────────────────

final _intake = col([
  bar(),
  _gutter([
    _letterhead('DEVICE INTAKE', [
      ('Ticket', '#{{ticket.number}}'),
      ('Received', '{{ticket.date}}'),
      ('Received by', '{{ticket.received_by}}'),
      ('Location', '{{ticket.location}}'),
    ]),
  ], padY: 26, gap: 8),
  _gutter([rule()]),
  _gutter([
    row([
      field('Customer', '{{customer.name}}',
          sub:
              '{{customer.phone}} · {{customer.email}}\n{{customer.address}}',
          flex: 1),
      field('Device', '{{device.name}}',
          sub:
              'Serial {{device.serial}} · IMEI {{device.imei}}\nColour {{device.color}}',
          flex: 1),
    ], align: 'start', gap: 24),
    heading('Condition on arrival'),
    row([
      field('Condition', '{{device.condition}}', size: 9.5, flex: 1),
      field('Accessories received', '{{device.accessories}}',
          size: 9.5, flex: 1),
      field('Passcode / pattern', '{{device.passcode}}', size: 9.5, flex: 1),
    ], align: 'start', gap: 16),
    heading('Reported fault'),
    text('{{repair.description}}', size: 9.5, lineHeight: 1.6),
    heading('Pre-repair checks'),
    row([
      col([
        check('Powers on'),
        check('Touch responds'),
        check('Buttons and switches'),
        check('Battery health {{device.battery_health}}'),
      ], gap: 8, flex: 1),
      col([
        check('Screen intact / no cracks'),
        check('Front & rear cameras'),
        check('Liquid damage indicator'),
        check('Customer confirms backup taken'),
      ], gap: 8, flex: 1),
    ], align: 'start', gap: 16),
    heading('Authorization'),
    text(
        'Authorized repair limit: {{estimate.total}} {{estimate.currency}}',
        size: 9.5,
        weight: '600'),
    check('Proceed with the repair up to the authorized limit above.'),
    check('Contact me for approval before exceeding the estimate.'),
    check(
        'Return the device unrepaired if I decline — diagnostic fee {{ticket.diagnostic_fee}} {{estimate.currency}} applies.'),
    heading('Terms of service'),
    row([
      text(
          '1. Data & backups — the customer is responsible for backing up all data before service; we are not liable for data loss.\n'
          '2. Estimates — estimates are valid for 14 days. Work exceeding the authorized limit requires renewed approval.\n'
          '3. Collection — devices not collected within 90 days of completion may be sold or recycled to cover repair and storage costs.\n'
          '4. Warranty — repairs carry a {{repair.warranty_months}}-month warranty on parts and labour fitted by us. It does not cover new physical or liquid damage.\n'
          '5. Parts — replaced parts become the property of {{company.name}} unless requested at intake.\n'
          '6. Privacy — personal data is processed only to deliver and document this repair, per {{company.name}}’s privacy policy.',
          size: 7.5,
          color: '#334155',
          lineHeight: 1.7,
          flex: 1),
      col([
        qr('{{ticket.tracking_url}}', size: 100),
        text('Track your repair\n#{{ticket.number}}',
            size: 7.5, color: kMuted, textAlign: 'center'),
      ], gap: 4, align: 'center'),
    ], align: 'start', gap: 16),
    row([
      sig('Customer signature — terms accepted', flex: 2),
      sig('Date', flex: 1),
      sig('Received by {{ticket.received_by}}', flex: 1),
    ], align: 'start', gap: 16),
    _footer(
        '{{company.name}} · VAT {{company.vat_number}} · Org.nr {{company.org_number}} · {{company.website}}\nKeep this receipt — it is required when collecting the device.'),
  ], padY: 16, gap: 12),
]);

// ── Labels ───────────────────────────────────────────────────────────────────

final _ticketLabel = col([
  bar(height: 4),
  col([
    row([
      qr('{{ticket.tracking_url}}', size: 70),
      col([
        text('{{company.name}}', size: 8, color: kMuted, weight: '600'),
        text('{{device.name}}', size: 10, weight: 'bold'),
        text('{{customer.name}}', size: 8.5),
        text('#{{ticket.number}}', size: 9, weight: '600'),
        text('{{ticket.status}} · {{ticket.priority}}',
            size: 7, color: kMuted),
      ], gap: 2, flex: 1),
    ], align: 'start', gap: 6),
    barcode('{{ticket.number}}',
        width: 218, height: 44, format: 'CODE128'),
    row([
      text('In {{ticket.date}} · {{ticket.received_by}}',
          size: 7, color: kMuted, flex: 1),
      text('{{device.imei}}', size: 7, color: kMuted, textAlign: 'right'),
    ]),
  ], padX: 6, padY: 6, gap: 6),
]);

final _purchaseLabel = col([
  bar(height: 4),
  col([
    row([
      text('DEVICE PURCHASE',
          size: 7.5, weight: 'bold', color: kAccent, tracking: 0.8, flex: 1),
      text('#{{purchase.number}}',
          size: 9, weight: 'bold', textAlign: 'right'),
    ]),
    row([
      text('{{device.name}}', size: 10, weight: 'bold', flex: 1),
      text('{{purchase.price}} {{purchase.currency}}',
          size: 10, weight: 'bold', textAlign: 'right'),
    ]),
    text('IMEI {{device.imei}} · SN {{device.serial}}',
        size: 7, color: kMuted),
    row([
      text('{{customer.name}}', size: 8.5, weight: '600', flex: 1),
      text('Grade {{product.grade}}',
          size: 8, color: kMuted, textAlign: 'right'),
    ]),
    row([
      barcode('{{purchase.number}}',
          width: 160, height: 50, format: 'CODE128', flex: 1),
      qr('{{purchase.number}}', size: 50),
    ], align: 'start', gap: 8),
    text(
        'Bought {{purchase.date}} · {{purchase.payout_method}} · ID checked: {{purchase.id_checked}}\n{{company.name}} · locked/blacklist check passed',
        size: 6.5,
        color: kMuted,
        lineHeight: 1.4),
  ], padX: 6, padY: 6, gap: 4),
]);

final _productLabel = col([
  row([
    text('{{product.name}}', size: 8.5, weight: 'bold', flex: 1),
    text('{{product.price}} {{product.currency}}',
        size: 9.5, weight: 'bold', textAlign: 'right'),
  ]),
  text('{{product.brand}} · {{product.grade}} · {{product.location}}',
      size: 6.5, color: kMuted),
  barcode('{{product.sku}}', width: 181, height: 42, format: 'CODE128'),
  row([
    text('{{product.warranty_months}} mo warranty',
        size: 6.5, color: kMuted, flex: 1),
    text('{{product.condition}}',
        size: 6.5, color: kMuted, textAlign: 'right'),
  ]),
], padX: 4, padY: 4, gap: 3);

/// Sample record used by tests and the proof render. Money and dates are
/// pre-formatted strings — the templates do no arithmetic.
final kRepairXSampleRecord = <String, dynamic>{
  'company.name': 'Northgate Device Care',
  'company.address': 'Storgatan 14, 114 51 Stockholm',
  'company.phone': '+46 8 555 0110',
  'company.email': 'service@northgate.example',
  'company.vat_number': 'SE556123456701',
  'company.org_number': '556123-4567',
  'company.website': 'northgate.example',
  'company.logo_url': '',
  'ticket.number': 'A7F2C9',
  'ticket.id': 'tk_9f2c81a7',
  'ticket.status': 'In progress',
  'ticket.priority': 'High',
  'ticket.date': '2026-08-13',
  'ticket.received_by': 'Alex Kim',
  'ticket.location': 'Stockholm · Counter 2',
  'ticket.tracking_url': 'https://track.northgate.example/A7F2C9',
  'ticket.diagnostic_fee': '295',
  'ticket.total': '4 490.00',
  'device.brand': 'Apple',
  'device.model': 'iPhone 14 Pro',
  'device.name': 'Apple iPhone 14 Pro',
  'device.serial': 'F17GQ2LMPL',
  'device.imei': '356789104523891',
  'device.color': 'Deep Purple',
  'device.passcode': 'held on file',
  'device.condition': 'Screen cracked, frame scuffed',
  'device.accessories': 'Silicone case, no SIM tray',
  'device.battery_health': '86%',
  'customer.name': 'Jonas Berglund',
  'customer.email': 'jonas.berglund@example.se',
  'customer.phone': '+46 70 123 45 67',
  'customer.address': 'Vasagatan 8, 111 20 Stockholm',
  'customer.contact': '+46 70 123 45 67',
  'repair.description':
      'Screen cracked after a drop; touch responds intermittently across the top third of the display.',
  'repair.diagnosis':
      'Display assembly damaged, digitizer flex partially delaminated. Frame straight, no logic-board damage, Face ID intact.',
  'repair.work_performed':
      'Replaced display assembly, transferred Face ID module, recalibrated True Tone, verified touch across full panel.',
  'repair.parts_replaced': 'Display assembly (OEM), waterproof adhesive kit',
  'repair.warranty_months': '12',
  'repair.technician': 'Alex Kim',
  'repair.completed_date': '2026-08-14',
  'invoice.number': 'INV-2026-0481',
  'invoice.date': '2026-08-13',
  'invoice.due_date': '2026-08-27',
  'invoice.currency': 'SEK',
  'invoice.subtotal': '3 592.00',
  'invoice.vat_rate': '25',
  'invoice.vat_total': '898.00',
  'invoice.total': '4 490.00',
  'invoice.amount_due': '4 490.00',
  'invoice.paid_amount': '0.00',
  'invoice.payment_terms': 'Net 14 days',
  'invoice.notes':
      'Warranty covers parts and labour for 12 months from the completion date. Keep this invoice as proof of repair.',
  'invoice.reference': 'Ticket A7F2C9',
  'invoice.lines': kRepairXSampleLines,
  'estimate.number': 'EST-2026-0193',
  'estimate.date': '2026-08-13',
  'estimate.valid_until': '2026-08-27',
  'estimate.currency': 'SEK',
  'estimate.subtotal': '3 592.00',
  'estimate.vat_rate': '25',
  'estimate.vat_total': '898.00',
  'estimate.total': '4 490.00',
  'estimate.approval_note':
      'A 295 SEK diagnostic fee applies if the estimate is declined.',
  'estimate.lines': kRepairXSampleLines,
  'insurance.claim_number': 'CLM-88420',
  'insurance.policy_number': 'HF-2291-778',
  'insurance.insurer': 'Folksam',
  'insurance.adjuster': 'M. Lind · ref 88420-2',
  'insurance.deductible': '1 500.00',
  'insurance.incident_date': '2026-08-09',
  'insurance.cause': 'Accidental drop onto a hard surface',
  'insurance.damage_report':
      'The device was dropped face-down onto concrete. The front glass and display assembly are cracked from the upper-left corner across the panel; the aluminium frame shows scuffing along the left rail. No liquid ingress indicators triggered, rear glass and camera assembly intact.',
  'insurance.assessment':
      'Damage is consistent with a single impact event as described. Repair is economical: display assembly replacement only. No board-level damage found on inspection.',
  'insurance.approved_amount': '2 990.00',
  'purchase.number': 'PUR-1042',
  'purchase.date': '2026-08-13',
  'purchase.price': '2 100',
  'purchase.currency': 'SEK',
  'purchase.payout_method': 'Swish',
  'purchase.id_checked': 'Yes',
  'product.sku': 'SCR-IP14P-OEM',
  'product.name': 'iPhone 14 Pro display (OEM)',
  'product.brand': 'Apple',
  'product.price': '1 790',
  'product.currency': 'SEK',
  'product.grade': 'A',
  'product.condition': 'Tested OK',
  'product.warranty_months': '6',
  'product.location': 'Shelf B3',
};

const kRepairXSampleLines = [
  {
    'description': 'Display assembly replacement — iPhone 14 Pro',
    'sku': 'SCR-IP14P-OEM',
    'qty': '1',
    'unit_price': '2 592.00',
    'vat_rate': '25',
    'amount': '2 592.00',
  },
  {
    'description': 'Labour — screen replacement (45 min)',
    'sku': 'LAB-SCR',
    'qty': '1',
    'unit_price': '700.00',
    'vat_rate': '25',
    'amount': '700.00',
  },
  {
    'description': 'Waterproof adhesive kit',
    'sku': 'ADH-IP14',
    'qty': '1',
    'unit_price': '120.00',
    'vat_rate': '25',
    'amount': '120.00',
  },
  {
    'description': 'Diagnostics & functional test',
    'sku': 'DIA-STD',
    'qty': '1',
    'unit_price': '180.00',
    'vat_rate': '25',
    'amount': '180.00',
  },
];
