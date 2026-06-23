import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CustomPaperSize {
  final String key;
  final String label;
  final double widthMm;
  final double heightMm;

  const CustomPaperSize({
    required this.key,
    required this.label,
    required this.widthMm,
    required this.heightMm,
  });

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'widthMm': widthMm,
        'heightMm': heightMm,
      };

  factory CustomPaperSize.fromJson(Map<String, dynamic> j) => CustomPaperSize(
        key: j['key'] as String,
        label: j['label'] as String,
        widthMm: (j['widthMm'] as num).toDouble(),
        heightMm: (j['heightMm'] as num).toDouble(),
      );
}

class PaperSizeService {
  static const _prefsKey = 'custom_paper_sizes';

  static Future<List<CustomPaperSize>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => CustomPaperSize.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(CustomPaperSize size) async {
    final existing = await getAll();
    existing.removeWhere((s) => s.key == size.key);
    existing.add(size);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(existing.map((s) => s.toJson()).toList()));
  }

  static Future<void> delete(String key) async {
    final existing = await getAll();
    existing.removeWhere((s) => s.key == key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(existing.map((s) => s.toJson()).toList()));
  }
}
