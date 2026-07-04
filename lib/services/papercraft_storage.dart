import '../models/template_model.dart';
import 'template_service.dart';

/// Pluggable template storage back-end.
///
/// The default implementation ([SharedPrefsStorage]) stores templates in
/// `SharedPreferences` on-device. Implement this class to store templates in
/// Appwrite, Firestore, a REST API, or any other back-end.
///
/// ```dart
/// class AppwriteTemplateStorage implements PapercraftStorage {
///   final Databases _db;
///   AppwriteTemplateStorage(this._db);
///
///   @override
///   Future<Template?> getById(String id) async {
///     try {
///       final doc = await _db.getDocument(
///         databaseId: 'repairx',
///         collectionId: 'templates',
///         documentId: id,
///       );
///       return Template.fromJson(doc.data);
///     } catch (_) {
///       return null;
///     }
///   }
///
///   @override
///   Future<Template> save(Template template) async {
///     await _db.updateDocument(
///       databaseId: 'repairx',
///       collectionId: 'templates',
///       documentId: template.id,
///       data: template.toJson(),
///     );
///     return template;
///   }
///
///   @override
///   Future<void> delete(String id) => _db.deleteDocument(
///     databaseId: 'repairx',
///     collectionId: 'templates',
///     documentId: id,
///   );
///
///   @override
///   Future<List<Template>> list({String? ownerId}) async {
///     final docs = await _db.listDocuments(
///       databaseId: 'repairx',
///       collectionId: 'templates',
///     );
///     return docs.documents
///         .map((d) => Template.fromJson(d.data))
///         .toList();
///   }
/// }
///
/// // Register at startup:
/// StorageRegistry.register(AppwriteTemplateStorage(databases));
/// ```
abstract class PapercraftStorage {
  /// Load a template by id. Returns null if not found.
  Future<Template?> getById(String id);

  /// Persist a template (create or update). Returns the saved template.
  Future<Template> save(Template template);

  /// Delete a template by id.
  Future<void> delete(String id);

  /// List all templates, optionally filtered by owner.
  Future<List<Template>> list({String? ownerId});
}

// ── Default on-device implementation ─────────────────────────────────────────

/// Default storage — wraps [TemplateService] (SharedPreferences).
/// Used automatically when no custom storage is registered.
class SharedPrefsStorage implements PapercraftStorage {
  const SharedPrefsStorage();

  @override
  Future<Template?> getById(String id) => TemplateService.getById(id);

  @override
  Future<Template> save(Template template) => TemplateService.update(template);

  @override
  Future<void> delete(String id) => TemplateService.delete(id);

  @override
  Future<List<Template>> list({String? ownerId}) =>
      ownerId != null ? TemplateService.list(ownerId) : Future.value([]);
}

// ── Registry ──────────────────────────────────────────────────────────────────

/// Global storage registry. Register your own [PapercraftStorage] at startup
/// to replace the default SharedPreferences storage.
///
/// ```dart
/// StorageRegistry.register(AppwriteTemplateStorage(databases));
/// ```
class StorageRegistry {
  StorageRegistry._();

  static PapercraftStorage _active = const SharedPrefsStorage();

  static PapercraftStorage get active => _active;

  static void register(PapercraftStorage storage) => _active = storage;
}
