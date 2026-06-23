import 'package:flutter/material.dart';
import '../../models/element_model.dart';
import '../../theme/app_colors.dart';

// CODE128B patterns (index 0–106, each 11 modules)
const _code128Patterns = [
  '11011001100', '11001101100', '11001100110', '10010011000', '10010001100',
  '10001001100', '10011001000', '10011000100', '10001100100', '11001001000',
  '11001000100', '11000100100', '10110011100', '10011011100', '10011001110',
  '10111001100', '10011101100', '10011100110', '11001110010', '11001011100',
  '11001001110', '11011100100', '11001110100', '11101101110', '11101001100',
  '11100101100', '11100100110', '11101100100', '11100110100', '11100110010',
  '11011011000', '11011000110', '11000110110', '10100011000', '10001011000',
  '10001000110', '10110001000', '10001101000', '10001100010', '11010001000',
  '11000101000', '11000100010', '10110111000', '10110001110', '10001101110',
  '10111011000', '10111000110', '10001110110', '11101110110', '11010001110',
  '11000101110', '11011101000', '11011100010', '11011101110', '11101011000',
  '11101000110', '11100010110', '11101101000', '11101100010', '11100011010',
  '11101111010', '11001000010', '11110001010', '10100110000', '10100001100',
  '10010110000', '10010000110', '10000101100', '10000100110', '10110010000',
  '10110000100', '10011010000', '10011000010', '10000110100', '10000110010',
  '11000010010', '11001010000', '11110111010', '11000010100', '10001111010',
  '10100111100', '10010111100', '10010011110', '10111100100', '10011110100',
  '10011110010', '11110100100', '11110010100', '11110010010', '11011011110',
  '11011110110', '11110110110', '10101111000', '10100011110', '10001011110',
  '10111101000', '10111100010', '11110101000', '11110100010', '10111011110',
  '10111101110', '11101011110', '11110101110', '11010000100', '11010010000',
  '11010011100', '1100011101011',  // index 106 = START B (11010111100), 107 = STOP
];

// Correct START B = '11010111100'
const _startBPattern = '11010111100';
const _stopPattern = '1100011101011';

String? _encode128B(String value) {
  final codes = <int>[];
  for (final c in value.runes) {
    final code = c - 32;
    if (code < 0 || code > 94) return null;
    codes.add(code);
  }

  // Checksum
  int sum = 104; // START B value
  for (int i = 0; i < codes.length; i++) {
    sum += codes[i] * (i + 1);
  }
  final checksum = sum % 103;

  final buffer = StringBuffer(_startBPattern);
  for (final code in codes) {
    if (code < _code128Patterns.length) {
      buffer.write(_code128Patterns[code]);
    }
  }
  if (checksum < _code128Patterns.length) {
    buffer.write(_code128Patterns[checksum]);
  }
  buffer.write(_stopPattern);
  return buffer.toString();
}

class BarcodePainter extends CustomPainter {
  final BarcodeElement el;

  BarcodePainter(this.el);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background
    final bgColor = _parseColor(el.background) ?? Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = bgColor);

    final binary = _encode128B(el.content);
    if (binary == null || binary.isEmpty) {
      // Invalid
      final p = Paint()..color = const Color(0xFFCCCCCC);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), p);
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Invalid barcode',
          style: TextStyle(fontSize: 10, color: Color(0xFF666666)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));
      return;
    }

    final textH = el.displayValue ? 14.0 : 0.0;
    final barH = h - textH - 4;
    final barWidth = w / binary.length;
    final barColor = _parseColor(el.color) ?? Colors.black;
    final barPaint = Paint()..color = barColor;

    for (int i = 0; i < binary.length; i++) {
      if (binary[i] == '1') {
        canvas.drawRect(
          Rect.fromLTWH(
              (i * barWidth).floorToDouble(), 2, barWidth.ceilToDouble(), barH),
          barPaint,
        );
      }
    }

    if (el.displayValue) {
      final tp = TextPainter(
        text: TextSpan(
          text: el.content,
          style: TextStyle(fontSize: 10, color: barColor),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: w);
      tp.paint(canvas, Offset((w - tp.width) / 2, h - 13));
    }
  }

  @override
  bool shouldRepaint(BarcodePainter old) =>
      old.el.content != el.content ||
      old.el.color != el.color ||
      old.el.background != el.background ||
      old.el.displayValue != el.displayValue;
}

Color? _parseColor(String hex) {
  try {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  } catch (_) {
    return null;
  }
}

Color hexToColor(String hex) => _parseColor(hex) ?? Colors.black;
