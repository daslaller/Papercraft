/// Papercraft — drop-in Flutter label/document designer.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// QUICK START
/// ─────────────────────────────────────────────────────────────────────────────
///
/// 1. Add to your app's pubspec.yaml:
///
///      dependencies:
///        papercraft:
///          path: ../papercraft
///
/// 2. Import the single barrel:
///
///      import 'package:papercraft/papercraft.dart';
///
/// 3. Register adapters once at startup (optional but recommended for RepairX):
///
///      void main() {
///        StorageRegistry.register(RepairXTemplateStorage(databases));
///        PrinterRegistry.register(CompositePrinterProvider([
///          const LocalPrinterProvider(),
///          ExternalPrinterProvider(list: () async => repairXPrinters),
///        ]));
///        AdapterRegistry.register(RepairXAdapter(databases));
///        runApp(MyApp());
///      }
///
/// Full consumer guide: see WIDGET_API.md in the package root.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WIDGET API  (recommended — no GoRouter required)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// [PapercraftEditor] is a self-contained widget. Put it anywhere:
///
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => Scaffold(
///       body: PapercraftEditor(
///         templateId: template.id,
///         onClose: () => Navigator.pop(context),
///         onSave: (t) => myState.refresh(),
///       ),
///     ),
///   ));
///
/// ─────────────────────────────────────────────────────────────────────────────
/// HEADLESS PRINT / RENDER  (no editor UI needed)
/// ─────────────────────────────────────────────────────────────────────────────
///
///   final template = await StorageRegistry.active.getById(id);
///   final elements = elementsFromJson(template!.elements);
///
///   // Inline preview:
///   PapercraftRenderer.fitted(template: template, elements: elements, record: record);
///
///   // PDF bytes:
///   final bytes = await PapercraftPrint.buildPdf(
///     template: template, elements: elements, record: record);
///
///   // Silent print to the template's associated printer:
///   await PapercraftPrint.printToAssociatedPrinter(
///     context: context, // optional — shows dialog if printer unavailable
///     template: template,
///     elements: elements,
///     record: record,
///   );
///
/// ─────────────────────────────────────────────────────────────────────────────
/// STORAGE + PRINTERS
/// ─────────────────────────────────────────────────────────────────────────────
///
///   StorageRegistry.register(myPapercraftStorage);
///   PrinterRegistry.register(myPrinterProvider);
///
/// Templates store [Template.printerName] and [Template.printerId].
/// Auto-print resolves them via [PrinterRegistry.active].
/// Missing local printers throw [PrinterUnavailableException].
///
/// ─────────────────────────────────────────────────────────────────────────────
/// TOKEN SYNTAX
/// ─────────────────────────────────────────────────────────────────────────────
///
///   {{order.number}}              →  "WO-4821"
///   {{customer.name|uppercase}}   →  "JOHN SMITH"
///   {{order.date|date:dd/MM/yy}}  →  "25/06/26"
///   {{product.price|trim}}        →  whitespace stripped

// ── Widget API ────────────────────────────────────────────────────────────────
export 'widgets/papercraft_data_source.dart';
export 'widgets/papercraft_editor.dart';
export 'widgets/papercraft_renderer.dart';
export 'widgets/papercraft_print.dart';

// ── Screen API (GoRouter-friendly) ───────────────────────────────────────────
export 'screens/editor_screen.dart';
export 'screens/dashboard_screen.dart';

// ── Models ────────────────────────────────────────────────────────────────────
export 'models/template_model.dart';
export 'models/element_model.dart';
export 'models/flow_layout.dart';
export 'models/gradient_def.dart';
export 'models/layout_helpers.dart';
export 'models/table_element.dart';
export 'models/table_layout.dart';

// ── Services ──────────────────────────────────────────────────────────────────
export 'services/template_service.dart';
export 'services/print_service.dart';
export 'services/data_source_adapter.dart';
export 'services/papercraft_storage.dart';
export 'services/printer_provider.dart';
export 'services/token_service.dart';
export 'services/paper_size_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
export 'state/editor_state.dart';

// ── Theme ─────────────────────────────────────────────────────────────────────
export 'theme/app_colors.dart';
export 'theme/app_theme.dart';
