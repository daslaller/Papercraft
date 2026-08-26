# Papercraft Widget API

Single import covers everything:

```dart
import 'package:papercraft/papercraft.dart';
```

Papercraft is designed to be the template source for host apps (e.g. RepairX): design in the embeddable editor, persist via a storage adapter, associate local or external printers, and print/render **without** mounting the editor.

---

## Setup

### 1. Add the dependency

```yaml
# your_app/pubspec.yaml
dependencies:
  papercraft:
    path: ../papercraft
```

### 2. Register adapters at startup (recommended)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  StorageRegistry.register(RepairXTemplateStorage(databases));
  PrinterRegistry.register(CompositePrinterProvider([
    const LocalPrinterProvider(),
    ExternalPrinterProvider(
      list: () async => repairXPrinters,
      onPrintPdf: (printer, bytes, {jobName}) async {
        await repairXPrintService.send(printer.id, bytes);
      },
    ),
  ]));
  AdapterRegistry.register(RepairXDataAdapter(databases));

  runApp(MyApp());
}
```

| Registry | Purpose | Default |
|----------|---------|---------|
| `StorageRegistry` | Template CRUD | `SharedPrefsStorage` |
| `PrinterRegistry` | List + print to printers | `LocalPrinterProvider` (OS) |
| `AdapterRegistry` | Data sidebar records | `MockDataAdapter` |

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

### Custom storage on one editor instance

```dart
PapercraftEditor(
  templateId: id,
  storage: myStorage, // overrides StorageRegistry.active for this instance
  onSave: (t) => syncToHost(t),
)
```

`onSave` fires after every successful persist (auto-save and explicit saves).

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
  mode: PapercraftMode.printReady,
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
| `onSave` | `void Function(Template)?` | null | Called after each successful save |
| `onPrint` | `void Function(Template, Map)?` | null | Called after confirming print |
| `controller` | `PapercraftController?` | null | Programmatic undo/redo/zoom/save |
| `storage` | `PapercraftStorage?` | `StorageRegistry.active` | Template I/O back-end |
| `showPropertiesPanel` | `bool` | true | Show/hide right properties panel |

### PapercraftMode values

| Mode | Description |
|------|-------------|
| `PapercraftMode.edit` | Full editor — toolbar, sidebars, canvas handles |
| `PapercraftMode.preview` | Read-only canvas — no chrome, no handles |
| `PapercraftMode.printReady` | Editor loads then immediately opens print dialog |

---

## DashboardScreen (embeddable template list)

The template dashboard — the "pick a template to edit" grid — is an embeddable
widget too. It renders/creates/deletes/duplicates templates via
`StorageRegistry.active` (your storage adapter) and hands editing back to you via
`onOpen`. No router or auth dependency — the host owns navigation and identity.

```dart
DashboardScreen(
  ownerId: currentUserOrTenantId,          // whose templates to list/create
  onOpen: (templateId) => Navigator.push(  // host pushes the editor
    context,
    MaterialPageRoute(builder: (_) => Scaffold(
      body: PapercraftEditor(templateId: templateId, onClose: () => Navigator.pop(context)),
    )),
  ),
  onExit: () => Navigator.pop(context),     // optional; hides the navbar's close button when null
  appName: 'RepairX',                        // navbar brand (default 'Papercraft')
  logo: const MyBrandMark(),                 // optional brand logo widget
  showChrome: true,                          // false embeds the grid without the navbar
  embedded: false,                           // true = bare picker for a host settings page
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ownerId` | `String` | required | Owner id passed to storage `list`/`create`/`duplicate` |
| `onOpen` | `void Function(String templateId)` | required | Open a template — host pushes the editor |
| `onExit` | `VoidCallback?` | null | Navbar close/back action; hidden when null |
| `showChrome` | `bool` | true | Show the top navbar (brand + New Template) |
| `embedded` | `bool` | false | Bare picker: no Scaffold/navbar/hero and no internal scrolling — the filter bar + grid shrink-wrap so the host scroll view owns scrolling. Grid columns follow the width the host grants. Ignores `showChrome`/`onExit`/`appName`/`logo` |
| `appName` | `String` | `'Papercraft'` | Brand name in the navbar |
| `logo` | `Widget?` | null | Brand logo shown before `appName` |

Theming: the dashboard (and the whole library) paints from `AppColors`. Host apps
that vendor Papercraft reskin by swapping `theme/app_colors.dart` for their own
palette; the rest of the library syncs from upstream unchanged.

## Template storage adapter

Implement `PapercraftStorage` and register it so all create/load/save/list/delete/duplicate goes through your backend.

```dart
abstract class PapercraftStorage {
  Future<Template?> getById(String id);
  Future<Template> save(Template template);
  Future<Template> create({
    required String name,
    required String docType,
    required String canvasSize,
    required double widthMm,
    required double heightMm,
    required String ownerId,
    String? printerName,
    String? printerId,
  });
  Future<void> delete(String id);
  Future<List<Template>> list({String? ownerId});
  Future<Template> duplicate(Template template, String ownerId);
  Future<void> seedDefaults(String ownerId); // optional
}
```

```dart
StorageRegistry.register(AppwriteTemplateStorage(databases));

// Create without the dashboard UI:
final template = await StorageRegistry.active.create(
  name: 'Repair Ticket',
  docType: 'document',
  canvasSize: 'A4',
  widthMm: 210,
  heightMm: 297,
  ownerId: currentUserId,
  printerName: 'Shop Laser',
  printerId: 'printer_shop_laser',
);
```

---

## Printer association (local + external)

Templates store `printerName` and optional `printerId`. Association UI lists printers from `PrinterRegistry`.

```dart
class PapercraftPrinter {
  final String id;
  final String name;
  final bool isLocal; // OS vs host-managed
  // ...
}

abstract class PrinterProvider {
  Future<List<PapercraftPrinter>> listPrinters();
  Future<void> printPdf(PapercraftPrinter printer, Uint8List bytes, {String? jobName});
  Future<PapercraftPrinter?> resolveAssociated(Template template);
}
```

Built-ins:

- `LocalPrinterProvider` — `Printing.listPrinters()` + `directPrintPdf`
- `ExternalPrinterProvider` — host-supplied list + optional print handler
- `CompositePrinterProvider` — merge several providers (dedupe by id)

Associate in the editor bottom bar, new-template “From Printer” flow, or print preview dropdown. Persist goes through the storage adapter.

---

## Headless use (no editor)

You do **not** need `PapercraftEditor` to preview or print.

### Load + render inline

```dart
final template = await StorageRegistry.active.getById(id);
if (template == null) return;
final elements = elementsFromJson(template.elements);

PapercraftRenderer.fitted(
  template: template,
  elements: elements,
  record: {
    'customer.name': 'Jane Doe',
    'order.number': 'WO-4821',
  },
  entityName: 'orders',
);
```

### PDF bytes

```dart
final bytes = await PapercraftPrint.buildPdf(
  template: template,
  elements: elements,
  record: record,
  entityName: 'orders',
);
```

### Auto-print to the template’s associated printer

```dart
try {
  await PapercraftPrint.printToAssociatedPrinter(
    context: context, // optional — shows themed error dialog on failure
    template: template,
    elements: elements,
    record: record,
  );
} on PrinterUnavailableException catch (e) {
  // Local printer missing / offline / not associated
  // If context was passed, a dialog was already shown.
}
```

Without `context`, the method only throws — suitable for service / background code.

Also available: `PapercraftPrint.print` (OS dialog), `printBatch`, `printSheet`, `buildPdfBatch`, `buildSheetPdf`.

---

## PapercraftDataSource

```dart
PapercraftDataSource(
  entityName: 'work_order',
  fields: {
    'work_order.number': 'WO-4821',
    'customer.name':     'Jane Doe',
  },
  computedFields: [
    ComputedField(name: 'vat', formula: 'price * 0.21'),
  ],
)
```

Keys must follow `namespace.field` to match `{{namespace.field}}` tokens.

---

## Data adapter (sidebar picker)

```dart
class RepairXAdapter extends AppwriteAdapterBase {
  @override String get displayName => 'RepairX';

  @override
  Future<List<String>> listEntities() async =>
      ['work_orders', 'devices', 'customers'];

  @override
  Future<List<DataRecord>> fetchRecords(String entity, {int limit = 10}) async {
    // return DataRecord(displayName, subtitle, flat: {...})
  }
}

AdapterRegistry.register(RepairXAdapter(databases));
```

Connection indicator in the left sidebar:

- **Green** — real adapter active (`displayName`)
- **Amber** — `MockDataAdapter` (design mode)
- **Red** — explicitly disconnected

---

## Token syntax

| Token | Example | Output |
|-------|---------|--------|
| `{{namespace.field}}` | `{{order.number}}` | field value |
| `{{field\|uppercase}}` | `{{customer.name\|uppercase}}` | `JANE DOE` |
| `{{field\|date:dd/MM/yy}}` | `{{order.date\|date:dd/MM/yy}}` | `25/06/26` |
| `{{field\|trim}}` | `{{product.sku\|trim}}` | whitespace stripped |

Headless resolution:

```dart
TokenService.resolveTokens(content, record, entityName, computedFields);
```

---

## Corner radius

Shape, image, row, and col elements support:

- **Uniform** — single `borderRadius` (linked)
- **Per corner** — `borderRadiusTL` / `TR` / `BR` / `BL`

Serialized in template JSON; older templates with only `borderRadius` remain valid.

---

## Viewport behavior

- Panning the document clamps so a minimum portion of the page stays visible.
- Dragging elements near the viewport edge auto-pans the workspace.

---

## Paper sizes

Built-in canvas sizes: `kCanvasSizes` on `Template` / `template_model.dart`.

Custom sizes (user-defined, SharedPreferences):

```dart
final custom = await PaperSizeService.getAll(); // List<CustomPaperSize>
await PaperSizeService.save(CustomPaperSize(...));
```

---

## Design system

Light theme tokens: `AppColors` + `AppTheme.light`. Host apps embedding chrome around Papercraft should wrap with `Theme(data: AppTheme.light, …)` or reuse the same tokens so dialogs and accents stay consistent. Dark mode is not implemented yet.

---

## PapercraftController

```dart
final ctrl = PapercraftController();

PapercraftEditor(templateId: id, controller: ctrl);

await ctrl.save();
ctrl.undo();
ctrl.redo();
ctrl.zoomIn();
```

---

## Line items (`table` element)

Invoice, estimate, and insurance documents bind a repeating row list with a `table` element. Row data travels on the same print `record` the tokens come from:

```json
{
  "type": "table",
  "rowSource": "invoice.lines",
  "columns": [
    { "key": "description", "label": "Description", "flex": 6, "align": "left" },
    { "key": "qty",         "label": "Qty",         "flex": 1, "align": "right" },
    { "key": "amount",      "label": "Amount",      "flex": 1.8, "align": "right" }
  ],
  "headerHeight": 24, "rowHeight": 22,
  "headerFontSize": 8, "headerColor": "#64748B", "headerBackground": "#F1F5F9",
  "gridColor": "#E2E8F0", "gridWidth": 0.5, "cellPaddingX": 6
}
```

`record['invoice.lines']` is a `List<Map>` with those column keys as pre-formatted strings. Missing/empty lists still draw the header (and `emptyText`); `maxRows: 0` (the default) means no cap — a flow table paginates instead of dropping rows.

`tokensIn` / `missingTokens` also report `rowSource` keys (`invoice.lines`) so a host can see that the record needs a list, not only `{{tokens}}`.

---

## Authoring defaults (row/col DSL)

Hand-writing absolute `x`/`y` JSON is how a default becomes unmaintainable. `compileTemplate` turns a nested row/column spec into the same element list the editor stores:

```dart
final elements = compileTemplate(
  col([
    bar(),
    row([
      text('{{company.name}}', size: 20, weight: 'bold', flex: 3),
      text('INVOICE', size: 24, textAlign: 'right', flex: 2),
    ]),
    rule(),
    table('invoice.lines', columns: kRepairXLineColumns),
  ]),
  idPrefix: 'invoice',
);
assertFlowOnly(elements);
```

The compiler also accepts a raw element object (`{"type": "table", "rowSource": "invoice.lines", ...}`) so line-items JSON dropped into a spec is not rejected. Output is flow-only (no `x`/`y`), which is what lets `PrintService.buildPdf` paginate.

Seven RepairX defaults ship as DSL specs on `kRepairXDefaultTemplates`. Seed them with:

```dart
for (final def in kRepairXDefaultTemplates) {
  await storage.save(def.toTemplate(ownerId: companyId));
}
```

`docRole` (`invoice`, `estimate`, `insurance`, `intake`, `ticket_label`, `purchase_label`, `product_label`) is how a host tells four A4 documents apart — they all share `docType: 'document'`. `withAccent(elementsJson, companyAccent)` rewrites the baked `#2563EB` bar.

---

## RepairX integration recipe

1. Register `PapercraftStorage` backed by your DB.
2. Register `CompositePrinterProvider` (local OS + RepairX printers).
3. Seed `kRepairXDefaultTemplates` (or compile your own DSL specs) and set `docRole` / `isDefault` per slot.
4. Put line items on the print record as `invoice.lines` / `estimate.lines` — `List<Map>` with `description`, `sku`, `qty`, `unit_price`, `vat_rate`, `amount`.
5. Embed `PapercraftEditor` for design; use `onSave` to refresh host lists.
6. For work-order print flows, load the template + elements and call `PapercraftPrint.printToAssociatedPrinter` — no editor required.
7. On `PrinterUnavailableException`, show your own UI or rely on the built-in dialog when you pass `context`.
