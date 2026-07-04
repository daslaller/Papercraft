# Papercraft Widget API

Import once:

```dart
import 'package:base44_flutter_label_creator/papercraft.dart';
```

---

## PapercraftEditor

Full label/document editor widget. No GoRouter dependency — drop it anywhere.

```dart
PapercraftEditor(
  templateId: 'tmpl_abc123',
  onClose: () => Navigator.pop(context),
  onSaved: (id) => myState.refresh(),
  showDataSidebar: true,       // default true — hide if you supply records yourself
  showPropertiesPanel: true,   // default true
)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `templateId` | `String` | Template to load (created via `TemplateService.create`) |
| `onClose` | `VoidCallback?` | Back button handler. If null, back button is hidden |
| `onSaved` | `void Function(String)?` | Called after each print-preview save |
| `showDataSidebar` | `bool` | Show/hide the left data-source sidebar |
| `showPropertiesPanel` | `bool` | Show/hide the right properties panel |

Full-page example:

```dart
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Scaffold(
    body: PapercraftEditor(
      templateId: template.id,
      onClose: () => Navigator.pop(context),
    ),
  ),
));
```

Embedded alongside your own UI:

```dart
Row(children: [
  MyRepairXSidebar(),
  Expanded(
    child: PapercraftEditor(
      templateId: id,
      showDataSidebar: false,
    ),
  ),
]);
```

---

## PapercraftRenderer

Read-only canvas render — no editor chrome, no handles, no toolbar.
Use for list thumbnails, dashboards, confirmation screens.

```dart
// Fixed scale:
PapercraftRenderer(
  template: template,
  elements: elements,
  record: {
    'customer.name': 'Jane Doe',
    'order.number':  'WO-4821',
  },
  entityName: 'orders',
  scale: 0.3,   // 30% of canvas pixel size
)

// Auto-fit into available space:
PapercraftRenderer.fitted(
  template: template,
  elements: elements,
  record: record,
  maxScale: 1.0,
)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `template` | `Template` | Template metadata |
| `elements` | `List<CanvasElement>` | Canvas elements to render |
| `record` | `Map<String, dynamic>?` | Flat `'namespace.field'` → value map |
| `entityName` | `String?` | Entity context for token resolution |
| `computedFields` | `List<ComputedField>` | Formula-derived fields |
| `scale` | `double` | Scale factor (1.0 = full canvas px size) |

---

## PapercraftPrint

Programmatic print / PDF generation — no UI shown.

```dart
// Open OS print dialog:
await PapercraftPrint.print(
  template: template,
  elements: elements,
  record: {
    'customer.name': 'Jane Doe',
    'order.number':  'WO-4821',
  },
);

// Get raw PDF bytes (upload, email, store yourself):
final Uint8List bytes = await PapercraftPrint.buildPdf(
  template: template,
  elements: elements,
  record: record,
  entityName: 'orders',
);
```

Both methods accept the same parameters:

| Parameter | Type | Description |
|-----------|------|-------------|
| `template` | `Template` | Template metadata |
| `elements` | `List<CanvasElement>` | Canvas elements |
| `record` | `Map<String, dynamic>?` | Flat field map |
| `entityName` | `String?` | Token resolution context |
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
  printerName: 'HP LaserJet', // optional — associates with a printer
);
```

---

## Data adapter

Register once at startup; the left-sidebar record picker uses it automatically.

```dart
// Extend the Appwrite stub:
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

// main.dart:
AdapterRegistry.register(RepairXAdapter(databases));
```

Connection indicator in the sidebar:
- **Green** = real adapter registered (shows `adapter.displayName`)
- **Amber** = `MockDataAdapter` active (offline / design mode)
- **Red** = explicitly disconnected

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

- [ ] Multi-record batch print (one page per record)
- [ ] Label sheet layout (N-up, e.g. 30 labels per A4)
- [ ] Cloud template sync adapter (`PapercraftStorage` interface)
- [ ] `PapercraftMode.preview` / `printReady` on `PapercraftEditor`
- [ ] `PapercraftController` for programmatic undo/redo/save
- [ ] Barcode auto-detection from field value
