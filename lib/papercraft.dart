/// Papercraft — drop-in Flutter label/document designer.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// QUICK START
/// ─────────────────────────────────────────────────────────────────────────────
///
/// 1. Add to your app's pubspec.yaml:
///
///      dependencies:
///        base44_flutter_label_creator:
///          path: ../base44_flutter_label_creator
///
/// 2. Import the single barrel:
///
///      import 'package:base44_flutter_label_creator/papercraft.dart';
///
/// 3. Register your data adapter once at startup (optional):
///
///      void main() {
///        AdapterRegistry.register(RepairXAdapter(databases));
///        runApp(MyApp());
///      }
///
/// ─────────────────────────────────────────────────────────────────────────────
/// WIDGET API  (recommended — no GoRouter required)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// [PapercraftEditor] is a self-contained widget. Put it anywhere:
///
///   // Full-page via plain Navigator:
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => Scaffold(
///       body: PapercraftEditor(
///         templateId: template.id,
///         onClose: () => Navigator.pop(context),
///         onSaved: (id) => myState.refresh(),
///       ),
///     ),
///   ));
///
///   // Embedded alongside your own UI:
///   Row(children: [
///     MyRepairXSidebar(),
///     Expanded(
///       child: PapercraftEditor(
///         templateId: id,
///         showDataSidebar: false,   // hide if RepairX supplies the record
///       ),
///     ),
///   ]);
///
/// ─────────────────────────────────────────────────────────────────────────────
/// SCREEN API  (for GoRouter users)
/// ─────────────────────────────────────────────────────────────────────────────
///
/// [EditorScreen] wraps [PapercraftEditor] in a [Scaffold] and requires an
/// explicit [onBack] callback — it no longer assumes any routing setup:
///
///   // Inside a GoRouter route:
///   GoRoute(
///     path: '/editor/:id',
///     builder: (ctx, state) => EditorScreen(
///       templateId: state.pathParameters['id']!,
///       onBack: () => ctx.go('/templates'),
///     ),
///   )
///
///   // Or with plain Navigator (onBack defaults to Navigator.maybePop):
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => EditorScreen(templateId: id),
///   ));
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CREATING A TEMPLATE
/// ─────────────────────────────────────────────────────────────────────────────
///
///   final template = await TemplateService.create(
///     name: 'Repair Ticket',
///     docType: 'document',        // 'label' | 'document'
///     canvasSize: 'A4',
///     widthMm: 210,
///     heightMm: 297,
///     ownerId: currentUserId,
///     printerName: 'HP LaserJet', // optional — associates template with printer
///   );
///
/// ─────────────────────────────────────────────────────────────────────────────
/// BATCH PDF / SILENT PRINT  (no editor UI needed)
/// ─────────────────────────────────────────────────────────────────────────────
///
///   final Uint8List bytes = await PrintService.buildPdf(
///     template: template,
///     elements: template.elements,
///     record: {                        // flat map — keys match {{tokens}}
///       'product.name': 'iPhone 15 Screen',
///       'order.number': 'WO-4821',
///       'customer.name': 'John Smith',
///     },
///   );
///
///   // Or open the OS print dialog directly:
///   await PrintService.printDirect(
///     template: template,
///     elements: template.elements,
///     record: record,
///   );
///
/// ─────────────────────────────────────────────────────────────────────────────
/// DATA ADAPTER  (wiring your back-end)
/// ─────────────────────────────────────────────────────────────────────────────
///
///   // Extend the Appwrite stub — only implement the two abstract methods:
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
///         subtitle:    d.data['status'] ?? '',
///         flat:        _flatten(d.data),
///       )).toList();
///     }
///
///     // Flatten nested Appwrite maps → 'customer.name' token keys.
///     Map<String, dynamic> _flatten(Map<String, dynamic> m, [String p = '']) {
///       final out = <String, dynamic>{};
///       for (final e in m.entries) {
///         final key = p.isEmpty ? e.key : '$p.${e.key}';
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
///   // Register once, the sidebar picker uses it automatically:
///   AdapterRegistry.register(RepairXAdapter(databases));
///
/// ─────────────────────────────────────────────────────────────────────────────
/// TOKEN SYNTAX  (text elements on the canvas)
/// ─────────────────────────────────────────────────────────────────────────────
///
///   {{order.number}}              →  "WO-4821"
///   {{customer.name|uppercase}}   →  "JOHN SMITH"
///   {{order.date|date:dd/MM/yy}}  →  "25/06/26"
///   {{product.price|trim}}        →  whitespace stripped
///
///   Call TokenService.resolveTokens(content, record, entity, computed)
///   yourself for custom rendering outside the editor.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CONNECTION STATUS INDICATOR  (left sidebar dot)
/// ─────────────────────────────────────────────────────────────────────────────
///
///   Green  = real adapter registered (shows adapter.displayName, e.g. "RepairX")
///   Amber  = MockDataAdapter active (offline / design mode)
///   Red    = user explicitly disconnected
///
/// ─────────────────────────────────────────────────────────────────────────────
/// PAPER SIZES
/// ─────────────────────────────────────────────────────────────────────────────
///
///   final sizes = PaperSizeService.all;      // List<PaperSize>
///   final a4    = PaperSizeService.find('A4');
///   // PaperSize exposes: id, label, widthMm, heightMm

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
export 'models/gradient_def.dart';
export 'models/layout_helpers.dart';

// ── Services ──────────────────────────────────────────────────────────────────
export 'services/template_service.dart';
export 'services/print_service.dart';
export 'services/data_source_adapter.dart';
export 'services/papercraft_storage.dart';
export 'services/token_service.dart';
export 'services/paper_size_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
export 'state/editor_state.dart';

// ── Theme ─────────────────────────────────────────────────────────────────────
export 'theme/app_colors.dart';
export 'theme/app_theme.dart';
