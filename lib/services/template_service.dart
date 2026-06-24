import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/template_model.dart';

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
    final elements = '''[
      {"id":"seed_1","type":"shape","x":0,"y":0,"width":383,"height":4,"rotation":0,"opacity":1,"zIndex":1,"shape":"rectangle","fill":"#6366f1","stroke":"#6366f1","strokeWidth":0,"borderRadius":0},
      {"id":"seed_2","type":"text","x":20,"y":16,"width":340,"height":36,"rotation":0,"opacity":1,"zIndex":2,"content":"SHIPPING LABEL","fontSize":22,"fontFamily":"Inter","fontWeight":"bold","fontStyle":"normal","textAlign":"left","color":"#1A1A1A","lineHeight":1.2},
      {"id":"seed_3","type":"text","x":20,"y":60,"width":160,"height":16,"rotation":0,"opacity":1,"zIndex":3,"content":"FROM","fontSize":9,"fontFamily":"Inter","fontWeight":"600","fontStyle":"normal","textAlign":"left","color":"#9E9890","lineHeight":1.2},
      {"id":"seed_4","type":"text","x":20,"y":76,"width":340,"height":60,"rotation":0,"opacity":1,"zIndex":4,"content":"Sender Name\\n123 Main St, City, ST 12345","fontSize":13,"fontFamily":"Inter","fontWeight":"normal","fontStyle":"normal","textAlign":"left","color":"#1A1A1A","lineHeight":1.5},
      {"id":"seed_5","type":"shape","x":20,"y":148,"width":343,"height":1,"rotation":0,"opacity":1,"zIndex":5,"shape":"line","fill":"#E8E6E1","stroke":"#E8E6E1","strokeWidth":1,"borderRadius":0},
      {"id":"seed_6","type":"text","x":20,"y":160,"width":160,"height":16,"rotation":0,"opacity":1,"zIndex":6,"content":"TO","fontSize":9,"fontFamily":"Inter","fontWeight":"600","fontStyle":"normal","textAlign":"left","color":"#9E9890","lineHeight":1.2},
      {"id":"seed_7","type":"text","x":20,"y":176,"width":340,"height":80,"rotation":0,"opacity":1,"zIndex":7,"content":"Recipient Name\\n456 Oak Ave, Town, ST 67890","fontSize":16,"fontFamily":"Inter","fontWeight":"bold","fontStyle":"normal","textAlign":"left","color":"#1A1A1A","lineHeight":1.5},
      {"id":"seed_8","type":"barcode","x":20,"y":310,"width":343,"height":60,"rotation":0,"opacity":1,"zIndex":8,"content":"1234567890","format":"CODE128","displayValue":true,"color":"#1A1A1A","background":"#ffffff"}
    ]''';

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key) ?? '[]';
    final all = (jsonDecode(json) as List).cast<Map<String, dynamic>>();

    final template = Template(
      id: const Uuid().v4(),
      name: 'Starter Shipping Label',
      docType: 'label',
      canvasSize: '4x6',
      canvasWidthMm: 101.6,
      canvasHeightMm: 152.4,
      backgroundColor: '#ffffff',
      elements: elements,
      ownerId: ownerId,
      createdDate: now,
      updatedDate: now,
    );

    all.add(template.toJson());
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
