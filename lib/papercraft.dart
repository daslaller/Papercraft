/// Papercraft — drop-in Flutter label/document designer for RepairX and other apps.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// QUICK START
/// ─────────────────────────────────────────────────────────────────────────────
///
/// 1. Add the package to your app's pubspec.yaml:
///
///      dependencies:
///        papercraft:
///          path: ../base44_flutter_label_creator
///
/// 2. Import the barrel:
///
///      import 'package:base44_flutter_label_creator/papercraft.dart';
///
/// 3. Register your data adapter at startup (optional — shows live records
///    from your back-end instead of the built-in sample data):
///
///      void main() {
///        AdapterRegistry.register(RepairXAppwriteAdapter());
///        runApp(MyApp());
///      }
///
/// ─────────────────────────────────────────────────────────────────────────────
/// OPENING THE EDITOR
/// ─────────────────────────────────────────────────────────────────────────────
///
///   // 1. Create a template (stored in SharedPreferences):
///   final template = await TemplateService.create(
///     name: 'Repair Ticket',
///     docType: 'document',        // 'label' | 'document'
///     canvasSize: 'A4',
///     widthMm: 210,
///     heightMm: 297,
///     ownerId: currentUserId,
///     printerName: 'HP LaserJet',  // optional — links template to a printer
///   );
///
///   // 2. Push the editor screen:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => EditorScreen(templateId: template.id),
///   ));
///
/// ─────────────────────────────────────────────────────────────────────────────
/// GENERATING A PDF PROGRAMMATICALLY
/// ─────────────────────────────────────────────────────────────────────────────
///
///   // Useful for batch printing from RepairX without opening the editor:
///   final Uint8List pdfBytes = await PrintService.buildPdf(
///     template: template,
///     elements: template.elements,   // already serialised in the Template
///     record: {                       // flat map — keys must match {{tokens}}
///       'product.name': 'iPhone 15 Screen',
///       'order.number': 'WO-4821',
///       'customer.name': 'John Smith',
///     },
///   );
///
///   // Print directly (opens OS print dialog):
///   await PrintService.printDirect(
///     template: template,
///     elements: template.elements,
///     record: record,
///   );
///
/// ─────────────────────────────────────────────────────────────────────────────
/// DATA ADAPTER — wiring in your back-end
/// ─────────────────────────────────────────────────────────────────────────────
///
///   // Extend AppwriteAdapterBase (or implement DataSourceAdapter directly):
///
///   class RepairXAdapter extends AppwriteAdapterBase {
///     final Databases _db;
///     RepairXAdapter(this._db);
///
///     @override
///     String get displayName => 'RepairX';
///
///     @override
///     Future<List<String>> listEntities() async =>
///         ['work_orders', 'devices', 'customers'];
///
///     @override
///     Future<List<DataRecord>> fetchRecords(
///         String entity, {int limit = 10}) async {
///       final docs = await _db.listDocuments(
///         databaseId: 'repairx',
///         collectionId: entity,
///         queries: [Query.limit(limit)],
///       );
///       return docs.documents.map((d) => DataRecord(
///         displayName: d.data['title'] ?? d.$id,
///         subtitle: d.data['status'] ?? '',
///         flat: _flatten(d.data),  // see _flatten() below
///       )).toList();
///     }
///
///     // Flatten nested maps so keys match {{namespace.field}} tokens.
///     // e.g. {'customer': {'name': 'John'}} → {'customer.name': 'John'}
///     Map<String, dynamic> _flatten(Map<String, dynamic> m, [String prefix = '']) {
///       final out = <String, dynamic>{};
///       for (final e in m.entries) {
///         final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
///         if (e.value is Map<String, dynamic>) {
///           out.addAll(_flatten(e.value as Map<String, dynamic>, key));
///         } else {
///           out[key] = e.value;
///         }
///       }
///       return out;
///     }
///   }
///
///   // Register at startup — the left-sidebar record picker will use it:
///   AdapterRegistry.register(RepairXAdapter(databases));
///
/// ─────────────────────────────────────────────────────────────────────────────
/// TOKEN SYNTAX (used in text elements on the canvas)
/// ─────────────────────────────────────────────────────────────────────────────
///
///   {{namespace.field}}          — replaced with the flat map value at that key
///   {{order.number}}             — e.g. "WO-4821"
///   {{customer.name|uppercase}}  — pipe transforms: uppercase / lowercase / trim
///   {{order.date|date:dd/MM/yy}} — date formatting
///
///   TokenService.resolveTokens(template, record, entityName) does the
///   substitution — call it yourself for custom rendering.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// PAPER SIZES
/// ─────────────────────────────────────────────────────────────────────────────
///
///   final sizes = PaperSizeService.all;   // List<PaperSize>
///   final a4   = PaperSizeService.find('A4');
///   // PaperSize has: id, label, widthMm, heightMm
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CONNECTION STATUS INDICATOR
/// ─────────────────────────────────────────────────────────────────────────────
///
///   The left sidebar shows:
///     • Green dot  = a real DataSourceAdapter is registered and active
///     • Amber dot  = MockDataAdapter is active (design / offline mode)
///     • Red dot    = explicitly disconnected (user pressed Disconnect)
///
///   The indicator label shows the adapter's displayName, so "RepairX" will
///   appear once you register RepairXAdapter.
///

// ── Models ────────────────────────────────────────────────────────────────────
export 'models/template_model.dart';
export 'models/element_model.dart';
export 'models/gradient_def.dart';
export 'models/layout_helpers.dart';

// ── Services ──────────────────────────────────────────────────────────────────
export 'services/template_service.dart';
export 'services/print_service.dart';
export 'services/data_source_adapter.dart';
export 'services/token_service.dart';
export 'services/paper_size_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
export 'state/editor_state.dart';

// ── Screens ───────────────────────────────────────────────────────────────────
export 'screens/editor_screen.dart';
export 'screens/dashboard_screen.dart';

// ── Theme ─────────────────────────────────────────────────────────────────────
export 'theme/app_colors.dart';
export 'theme/app_theme.dart';
