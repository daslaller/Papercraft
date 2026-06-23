# Papercraft Widget API

## Vision

Papercraft is designed to be embeddable as a Flutter widget. You drop it into your app, give it a data source, and it handles template editing, previewing, and printing. The host app controls data; Papercraft controls layout.

---

## Drop-in Editor Widget

```dart
PapercraftEditor(
  templateId: 'tmpl_abc123',          // which template to open
  dataSource: PapercraftDataSource(
    entityName: 'shipment',
    fields: {                          // live data record
      'tracking_number': 'TRK-00123',
      'recipient_name':  'Jane Doe',
      'recipient_addr':  '456 Oak Ave, Town ST 67890',
      'sender_name':     'ACME Corp',
      'weight_kg':       '1.4',
    },
    computedFields: [                  // optional formula fields
      ComputedField(name: 'weight_lb', formula: 'weight_kg * 2.20462'),
    ],
  ),
  mode: PapercraftMode.edit,           // .edit | .preview | .printReady
  onSave: (template) { ... },          // called after auto-save + manual save
  onPrint: (template, record) { ... }, // called when user taps Print
  onClose: () { ... },
)
```

### Modes

| Mode | Description |
|------|-------------|
| `edit` | Full editor with toolbar, panels, layers tree |
| `preview` | Read-only canvas render — no handles, no toolbar |
| `printReady` | Opens directly to print preview dialog |

---

## Read-only Renderer (embeddable anywhere)

Render a filled template inline — no editor chrome at all:

```dart
PapercraftRenderer(
  template: template,
  record: {
    'name': 'Jane Doe',
    'order_id': 'ORD-9921',
  },
  entityName: 'order',
  scale: 0.5,              // zoom scale relative to canvas mm size
  computedFields: [...],
)
```

Use this in list views to show a live thumbnail of each record.

---

## Print API

```dart
// Trigger print programmatically (skips preview dialog)
await PapercraftPrint.print(
  template: template,
  elements: elements,
  record: record,
  entityName: 'shipment',
  printerName: 'Zebra ZD420',   // null = OS default
);

// Get raw PDF bytes (for your own upload / email flow)
final Uint8List bytes = await PapercraftPrint.buildPdf(
  template: template,
  elements: elements,
  record: record,
);
```

---

## Data Source Contract

`PapercraftDataSource` describes one "entity" (a row from your DB, an API object, etc.):

```dart
class PapercraftDataSource {
  final String entityName;                  // e.g. 'shipment'
  final Map<String, dynamic> fields;        // current record values
  final List<ComputedField> computedFields; // formula-derived fields
  final List<String> fieldList;             // available field names for the left sidebar browser
}
```

Templates reference fields as `{{entityName.fieldName}}` or `{{computed:formulaName}}`.

---

## Template Storage

By default Papercraft stores templates in `SharedPreferences`. Provide your own adapter to store in a database, API, or cloud:

```dart
PapercraftEditor(
  storage: MyTemplateStorage(),   // implements PapercraftStorage
  ...
)

abstract class PapercraftStorage {
  Future<Template?> getById(String id);
  Future<Template> save(Template template);
  Future<void> delete(String id);
  Future<List<Template>> list({String? ownerId});
}
```

---

## Token Syntax

| Token | Example | Resolves to |
|-------|---------|-------------|
| `{{entity.field}}` | `{{shipment.recipient_name}}` | field value from record |
| `{{computed:name}}` | `{{computed:weight_lb}}` | formula result |
| Plain text | `TRACKING:` | literal |

Computed field formulas support: `+ - * / ( )`, field references by name, and `round()`.

---

## Roadmap

- [ ] Multi-record batch print (iterate a list, one page per record)
- [ ] Label sheet layout (N-up, e.g. 30 labels per A4 sheet)
- [ ] Cloud template sync adapter
- [ ] Barcode format auto-detection from field value
- [ ] Undo/redo exposed via `PapercraftController`
