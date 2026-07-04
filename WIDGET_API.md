# Papercraft Widget API

Single import covers everything:

```dart
import 'package:base44_flutter_label_creator/papercraft.dart';
```

---

## Setup

### 1. Add the dependency

```yaml
# your_app/pubspec.yaml
dependencies:
  base44_flutter_label_creator:
    path: ../base44_flutter_label_creator
```

### 2. Register your data adapter (optional — defaults to built-in mock data)

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AdapterRegistry.register(RepairXAdapter(databases)); // see Data Adapter section
  runApp(MyApp());
}
```

---

## PapercraftEditor

Full editor widget. Zero GoRouter dependency — embed it anywhere.

### Minimal usage

```dart
PapercraftEditor(
  templateId: template.id,
  onClose: () => Navigator.pop(context),
)
```

### With live data from your app

```dart
PapercraftEditor(
  templateId: template.id,
  dataSource: PapercraftDataSource(
    entityName: 'work_order',
    fields: {
      'work_order.number':  'WO-4821',
      'customer.name':      'Jane Doe',
      'device.model':       'iPhone 15',
      'repair.description': 'Cracked screen',
    },
    computedFields: [
      ComputedField(name: 'vat_total', formula: 'price * 1.21'),
    ],
  ),
  mode: PapercraftMode.edit,
  onSave:  (template) => myState.onTemplateSaved(template),
  onPrint: (template, record) => analytics.logPrint(template.id),
  onClose: () => Navigator.pop(context),
)
```

When `dataSource` is provided the left data-source sidebar is hidden — your
app is the source of truth. Tokens on the canvas resolve against `fields`.

### Read-only preview

```dart
PapercraftEditor(
  templateId: template.id,
  dataSource: dataSource,
  mode: PapercraftMode.preview,  // no editor chrome, canvas only
)
```

### Jump straight to print dialog

```dart
PapercraftEditor(
  templateId: template.id,
  dataSource: dataSource,
  mode: PapercraftMode.printReady,  // print dialog opens on load
  onClose: () => Navigator.pop(context),
)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `templateId` | `String` | required | Template to load |
| `dataSource` | `PapercraftDataSource?` | null | Live record + entity. When set, left sidebar is hidden |
| `mode` | `PapercraftMode` | `.edit` | Starting mode |
| `onClose` | `VoidCallback?` | null | Back button handler. If null back button is hidden |
| `onSave` | `void Function(Template)?` | null | Called after each save |
| `onPrint` | `void Function(Template, Map)?` | null | Called after confirming print |
| `showPropertiesPanel` | `bool` | true | Show/hide right properties panel |

### PapercraftMode values

| Mode | Description |
|------|-------------|
| `PapercraftMode.edit` | Full editor — toolbar, sidebars, canvas handles |
| `PapercraftMode.preview` | Read-only canvas — no chrome, no handles |
| `PapercraftMode.printReady` | Editor loads then immediately opens print dialog |

---

## PapercraftDataSource

Describes a live record to inject into the canvas.

```dart
PapercraftDataSource(
  entityName: 'work_order',           // matches token namespace {{work_order.x}}
  fields: {
    'work_order.number': 'WO-4821',   // key = namespace.field
    'customer.name':     'Jane Doe',
    'device.model':      'iPhone 15',
  },
  computedFields: [                   // optional formula fields
    ComputedField(name: 'vat', formula: 'price * 0.21'),
  ],
)
```

Keys in `fields` must follow the `namespace.field` convention to match
`{{namespace.field}}` tokens placed on the canvas.

---

## PapercraftRenderer

Read-only canvas widget. No editor chrome. Use for thumbnails, dashboards,
confirmation screens — anywhere you want to show a filled template inline.

```dart
// Fixed scale (1.0 = full canvas pixel size, which is large):
PapercraftRenderer(
  template: template,
  elements: elements,
  record: {'customer.name': 'Jane', 'order.number': 'WO-99'},
  entityName: 'orders',
  scale: 0.3,
)

// Auto-fit into the available space (recommended for most uses):
PapercraftRenderer.fitted(
  template: template,
  elements: elements,
  record: record,
  entityName: 'orders',
  maxScale: 1.0,   // never exceed 100%
)
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `template` | `Template` | required | Template metadata |
| `elements` | `List<CanvasElement>` | required | Canvas elements |
| `record` | `Map<String, dynamic>?` | null | Flat `'namespace.field'` → value map |
| `entityName` | `String?` | null | Token resolution context |
| `computedFields` | `List<ComputedField>` | `[]` | Formula-derived fields |
| `scale` | `double` | `1.0` | Scale factor |

`.fitted()` has an extra `maxScale` parameter (default `1.0`).

---

## PapercraftPrint

Print or export PDF without showing the editor UI.

```dart
// Open OS print dialog:
await PapercraftPrint.print(
  template: template,
  elements: elements,
  record: {
    'customer.name': 'Jane Doe',
    'order.number':  'WO-4821',
  },
  entityName: 'orders',
);

// Get raw PDF bytes (upload, email, archive):
final Uint8List bytes = await PapercraftPrint.buildPdf(
  template: template,
  elements: elements,
  record: record,
  entityName: 'orders',
);
```

Both methods share the same parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `template` | `Template` | Template metadata |
| `elements` | `List<CanvasElement>` | Canvas elements |
| `record` | `Map<String, dynamic>?` | Flat field map |
| `entityName` | `String?` | Token context |
| `computedFields` | `List<ComputedField>` | Formula fields |

---

## Creating a template

```dart
final template = await TemplateService.create(
  name: 'Repair Ticket',
  docType: 'document',        // 'label' | 'document'
  canvasSize: 'A4',
  widthMm: 210,
  heightMm: 297,
  ownerId: currentUserId,
  printerName: 'HP LaserJet', // optional — associates template with a printer
);
```

---

## Data adapter

Lets the built-in left sidebar picker load live records from your back-end.
Register once — the sidebar uses it automatically.

```dart
class RepairXAdapter extends AppwriteAdapterBase {
  final Databases _db;
  RepairXAdapter(this._db);

  @override String get displayName => 'RepairX';

  @override
  Future<List<String>> listEntities() async =>
      ['work_orders', 'devices', 'customers'];

  @override
  Future<List<DataRecord>> fetchRecords(String entity, {int limit = 10}) async {
    final docs = await _db.listDocuments(
      databaseId: 'repairx',
      collectionId: entity,
      queries: [Query.limit(limit)],
    );
    return docs.documents.map((d) => DataRecord(
      displayName: d.data['title'] ?? d.$id,
      subtitle:    d.data['status'] ?? '',
      flat:        _flatten(d.data),
    )).toList();
  }

  // Flatten nested maps: {'customer': {'name': 'x'}} → {'customer.name': 'x'}
  Map<String, dynamic> _flatten(Map<String, dynamic> m, [String p = '']) {
    final out = <String, dynamic>{};
    for (final e in m.entries) {
      final key = p.isEmpty ? e.key : '$p.${e.key}';
      if (e.value is Map<String, dynamic>) {
        out.addAll(_flatten(e.value as Map<String, dynamic>, key));
      } else {
        out[key] = e.value;
      }
    }
    return out;
  }
}

AdapterRegistry.register(RepairXAdapter(databases));
```

Connection indicator in the left sidebar:
- **Green** — real adapter active (shows `displayName`, e.g. "RepairX")
- **Amber** — MockDataAdapter active (offline / design mode)
- **Red** — explicitly disconnected

---

## Token syntax

| Token | Example | Output |
|-------|---------|--------|
| `{{namespace.field}}` | `{{order.number}}` | field value |
| `{{field\|uppercase}}` | `{{customer.name\|uppercase}}` | `JANE DOE` |
| `{{field\|date:dd/MM/yy}}` | `{{order.date\|date:dd/MM/yy}}` | `25/06/26` |
| `{{field\|trim}}` | `{{product.sku\|trim}}` | whitespace stripped |

---

## Paper sizes

```dart
final sizes = PaperSizeService.all;       // List<PaperSize>
final a4    = PaperSizeService.find('A4');
// PaperSize: id, label, widthMm, heightMm
```

---

## Roadmap

- [ ] Multi-record batch print (one page per record from a list)
- [ ] Label sheet layout (N-up, e.g. 30 labels per A4 page)
- [ ] `PapercraftStorage` interface for cloud/DB template storage
- [ ] `PapercraftController` for programmatic undo/redo/zoom/save
- [ ] Barcode auto-detection from field value type
