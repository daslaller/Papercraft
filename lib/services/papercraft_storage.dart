import 'package:uuid/uuid.dart';

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
///   Future<Template?> getById(String id) async { ... }
///
///   @override
///   Future<Template> save(Template template) async { ... }
///
///   @override
///   Future<Template> create({...}) async { ... }
///
///   @override
///   Future<void> delete(String id) async { ... }
///
///   @override
///   Future<List<Template>> list({String? ownerId}) async { ... }
///
///   @override
///   Future<Template> duplicate(Template template, String ownerId) async { ... }
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

  /// Create a new template with the given metadata.
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

  /// Delete a template by id.
  Future<void> delete(String id);

  /// List all templates, optionally filtered by owner.
  Future<List<Template>> list({String? ownerId});

  /// Duplicate [template] under [ownerId].
  Future<Template> duplicate(Template template, String ownerId);

  /// Seed demo templates for [ownerId] if the store is empty.
  /// Default no-op — override for local/dev storages.
  Future<void> seedDefaults(String ownerId) async {}
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
  Future<Template> create({
    required String name,
    required String docType,
    required String canvasSize,
    required double widthMm,
    required double heightMm,
    required String ownerId,
    String? printerName,
    String? printerId,
  }) =>
      TemplateService.create(
        name: name,
        docType: docType,
        canvasSize: canvasSize,
        widthMm: widthMm,
        heightMm: heightMm,
        ownerId: ownerId,
        printerName: printerName,
        printerId: printerId,
      );

  @override
  Future<void> delete(String id) => TemplateService.delete(id);

  @override
  Future<List<Template>> list({String? ownerId}) =>
      ownerId != null ? TemplateService.list(ownerId) : Future.value([]);

  @override
  Future<Template> duplicate(Template template, String ownerId) =>
      TemplateService.duplicate(template, ownerId);

  @override
  Future<void> seedDefaults(String ownerId) =>
      TemplateService.seedDefaults(ownerId);
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

  /// Reset to the default SharedPreferences storage (useful in tests).
  static void reset() => _active = const SharedPrefsStorage();
}

/// Convenience: generate a new template id for custom storage backends.
String newTemplateId() => const Uuid().v4();
