import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ComputedField {
  final String name;
  final String formula;

  const ComputedField({required this.name, required this.formula});

  Map<String, dynamic> toJson() => {'name': name, 'formula': formula};

  factory ComputedField.fromJson(Map<String, dynamic> j) =>
      ComputedField(name: j['name'] as String, formula: j['formula'] as String);
}

class TokenService {
  static final _tokenPattern = RegExp(r'\{\{([^}]+)\}\}');

  static String resolveTokens(
    String text,
    Map<String, dynamic>? record,
    String? entityName,
    List<ComputedField> computedFields,
  ) {
    if (record == null) return text;

    return text.replaceAllMapped(_tokenPattern, (m) {
      final path = m.group(1)!.trim();

      if (path.startsWith('computed:')) {
        final name = path.substring(9);
        final cf = computedFields.where((c) => c.name == name).firstOrNull;
        if (cf == null) return m.group(0)!;

        // Resolve formula tokens
        var formula = cf.formula.replaceAllMapped(
          _tokenPattern,
          (fm) {
            final fp = fm.group(1)!.trim();
            final val = _traverseRecord(record, fp.split('.'));
            return (double.tryParse(val.toString()) ?? 0).toString();
          },
        );

        // Safe eval: only allow digits, operators, spaces
        if (!RegExp(r'^[\d\s\+\-\*\/\(\)\.]+$').hasMatch(formula)) {
          return m.group(0)!;
        }
        try {
          final result = _evalSimple(formula);
          return (result * 100).round() / 100 == (result * 100).round() / 100
              ? result.toString()
              : m.group(0)!;
        } catch (_) {
          return m.group(0)!;
        }
      }

      // Direct field
      final parts = path.split('.');
      final val = _traverseRecord(record, parts);
      return val?.toString() ?? m.group(0)!;
    });
  }

  static dynamic _traverseRecord(Map<String, dynamic> record, List<String> parts) {
    dynamic current = record;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  static double _evalSimple(String expr) {
    // Very simple expression evaluator: handles +, -, *, /
    // Remove spaces
    expr = expr.replaceAll(' ', '');
    return _parseExpr(expr, [0]);
  }

  static double _parseExpr(String expr, List<int> pos) {
    double result = _parseTerm(expr, pos);
    while (pos[0] < expr.length) {
      final c = expr[pos[0]];
      if (c == '+') {
        pos[0]++;
        result += _parseTerm(expr, pos);
      } else if (c == '-') {
        pos[0]++;
        result -= _parseTerm(expr, pos);
      } else {
        break;
      }
    }
    return result;
  }

  static double _parseTerm(String expr, List<int> pos) {
    double result = _parseFactor(expr, pos);
    while (pos[0] < expr.length) {
      final c = expr[pos[0]];
      if (c == '*') {
        pos[0]++;
        result *= _parseFactor(expr, pos);
      } else if (c == '/') {
        pos[0]++;
        final divisor = _parseFactor(expr, pos);
        result = divisor != 0 ? result / divisor : 0;
      } else {
        break;
      }
    }
    return result;
  }

  static double _parseFactor(String expr, List<int> pos) {
    if (pos[0] < expr.length && expr[pos[0]] == '(') {
      pos[0]++;
      final result = _parseExpr(expr, pos);
      if (pos[0] < expr.length && expr[pos[0]] == ')') pos[0]++;
      return result;
    }
    if (pos[0] < expr.length && expr[pos[0]] == '-') {
      pos[0]++;
      return -_parseFactor(expr, pos);
    }
    int start = pos[0];
    while (pos[0] < expr.length &&
        (expr[pos[0]].contains(RegExp(r'[\d\.]')))) {
      pos[0]++;
    }
    if (start == pos[0]) return 0;
    return double.tryParse(expr.substring(start, pos[0])) ?? 0;
  }

  static Future<List<ComputedField>> loadComputedFields(String entityName) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('computed_$entityName') ?? '[]';
    return (jsonDecode(json) as List)
        .map((j) => ComputedField.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveComputedFields(
      String entityName, List<ComputedField> fields) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'computed_$entityName', jsonEncode(fields.map((f) => f.toJson()).toList()));
  }

  static bool validateFormula(String formula) {
    final sanitized = formula.replaceAll(_tokenPattern, '1');
    return RegExp(r'^[\d\s\+\-\*\/\(\)\.\,]+$').hasMatch(sanitized);
  }
}
