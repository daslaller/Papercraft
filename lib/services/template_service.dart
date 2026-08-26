import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/template_model.dart';
import '../templates/repairx_defaults.dart';

class TemplateService {
  static const _key = 'templates';

  static Future<List<Template>> list(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return all
        .where((t) => t['ownerId'] == ownerId)
        .map(Template.fromJson)
        .toList()
      ..sort((a, b) => b.updatedDate.compareTo(a.updatedDate));
  }

  static Future<Template?> getById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final match = all.where((t) => t['id'] == id).firstOrNull;
    return match != null ? Template.fromJson(match) : null;
  }

  static Future<Template> create({
    required String name,
    required String docType,
    required String canvasSize,
    required double widthMm,
    required double heightMm,
    required String ownerId,
    String? printerName,
    String? printerId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    final now = DateTime.now();
    final template = Template(
      id: const Uuid().v4(),
      name: name,
      docType: docType,
      canvasSize: canvasSize,
      canvasWidthMm: widthMm,
      canvasHeightMm: heightMm,
      printerName: printerName,
      printerId: printerId,
      ownerId: ownerId,
      createdDate: now,
      updatedDate: now,
    );

    all.add(template.toJson());
    await prefs.setString(_key, jsonEncode(all));
    return template;
  }

  static Future<Template> update(Template template) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    final updated = template.copyWith(updatedDate: DateTime.now());
    final idx = all.indexWhere((t) => t['id'] == template.id);
    if (idx >= 0) {
      all[idx] = updated.toJson();
    } else {
      all.add(updated.toJson());
    }
    await prefs.setString(_key, jsonEncode(all));
    return updated;
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    all.removeWhere((t) => t['id'] == id);
    await prefs.setString(_key, jsonEncode(all));
  }

  static Future<void> seedDefaults(String ownerId) async {
    final existing = await list(ownerId);
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    for (final def in kRepairXDefaultTemplates) {
      all.add(def.toTemplate(ownerId: ownerId, now: now).toJson());
    }

    await prefs.setString(_key, jsonEncode(all));
  }

  static Future<Template> duplicate(Template template, String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    final now = DateTime.now();
    final copy = Template(
      id: const Uuid().v4(),
      name: '${template.name} Copy',
      docType: template.docType,
      canvasSize: template.canvasSize,
      canvasWidthMm: template.canvasWidthMm,
      canvasHeightMm: template.canvasHeightMm,
      backgroundColor: template.backgroundColor,
      elements: template.elements,
      connectedEntity: template.connectedEntity,
      printerName: template.printerName,
      printerId: template.printerId,
      sectionLayoutEnabled: template.sectionLayoutEnabled,
      ownerId: ownerId,
      createdDate: now,
      updatedDate: now,
    );

    all.add(copy.toJson());
    await prefs.setString(_key, jsonEncode(all));
    return copy;
  }
}
