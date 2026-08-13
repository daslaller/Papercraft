import 'package:barcode/barcode.dart' as bc;
import 'package:flutter/material.dart';
import '../../models/element_model.dart';
import '../../services/font_registry.dart';
import '../../theme/app_colors.dart';

/// Paints a real QR code on the canvas.
///
/// Uses `package:barcode` — the same encoder `pdf`'s `pw.BarcodeWidget` uses
/// for the PDF — so the matrix a designer sees is the matrix that prints. The
/// canvas previously drew a decorative finder-pattern placeholder while the PDF
/// fetched a PNG from `api.qrserver.com`, which meant the editor and the label
/// showed two different things and neither was the scannable code.
class QrPainter extends CustomPainter {
  final String data;
  final Color color;

  const QrPainter({required this.data, this.color = Colors.black});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final side = size.shortestSide;
    if (side <= 0) return;

    final Iterable<bc.BarcodeElement> parts;
    try {
      parts = bc.Barcode.qrCode().make(data, width: side, height: side);
    } catch (_) {
      // Content the symbology cannot encode. Leave the area blank rather than
      // painting something that looks like a code but will not scan.
      return;
    }

    // Centre the square matrix in a non-square box.
    final dx = (size.width - side) / 2;
    final dy = (size.height - side) / 2;
    final paint = Paint()..color = color;

    for (final part in parts) {
      if (part is! bc.BarcodeBar || !part.black) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          dx + part.left,
          dy + part.top,
          // Nudge outward so adjacent modules meet — hairline gaps between
          // cells are what make a rendered QR fail to scan.
          part.width + 0.5,
          part.height + 0.5,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(QrPainter old) =>
      old.data != data || old.color != color;
}

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

/// Detects barcode format from content — mirrors PrintService._detectBarcode.
/// Returns: 'ean13' | 'ean8' | 'upca' | 'qr' | 'code128'
String detectBarcodeFormat(String content) {
  final onlyDigits = RegExp(r'^\d+$').hasMatch(content);
  if (onlyDigits) {
    // Length alone does not make a valid EAN/UPC — the check digit has to
    // match, and the encoders throw when it does not. Verify before choosing,
    // and fall through to Code 128, which accepts any digits. See
    // PrintService._detectBarcode, which this must stay in step with.
    if (content.length == 13 && _encodes(bc.Barcode.ean13(), content)) {
      return 'ean13';
    }
    if (content.length == 8 && _encodes(bc.Barcode.ean8(), content)) {
      return 'ean8';
    }
    if (content.length == 12 && _encodes(bc.Barcode.upcA(), content)) {
      return 'upca';
    }
  }
  if (content.startsWith('http') || content.length > 25) return 'qr';
  return 'code128';
}

bool _encodes(bc.Barcode barcode, String content) {
  try {
    barcode.verify(content);
    return true;
  } catch (_) {
    return false;
  }
}

// EAN-13 encoding tables
const _eanLeft_A = ['0001101','0011001','0010011','0111101','0100011',
                    '0110001','0101111','0111011','0110111','0001011'];
const _eanLeft_B = ['0100111','0110011','0011011','0100001','0011101',
                    '0111001','0000101','0010001','0001001','0010111'];
const _eanRight  = ['1110010','1100110','1101100','1000010','1011100',
                    '1001110','1010000','1000100','1001000','1110100'];
// First-digit parity patterns for EAN-13
const _eanParity = ['AAAAAA','AABABB','AABBAB','AABBBA','ABAABB',
                    'ABBAAB','ABBBAA','ABABAB','ABABBA','ABBABA'];

String? _encodeEan13(String value) {
  if (value.length != 13) return null;
  final digits = value.split('').map(int.tryParse).toList();
  if (digits.any((d) => d == null)) return null;
  final d = digits.cast<int>();

  final parity = _eanParity[d[0]];
  final buf = StringBuffer('101'); // start guard
  for (int i = 0; i < 6; i++) {
    buf.write(parity[i] == 'A' ? _eanLeft_A[d[i + 1]] : _eanLeft_B[d[i + 1]]);
  }
  buf.write('01010'); // centre guard
  for (int i = 7; i < 13; i++) {
    buf.write(_eanRight[d[i]]);
  }
  buf.write('101'); // end guard
  return buf.toString();
}

String? _encodeEan8(String value) {
  if (value.length != 8) return null;
  final digits = value.split('').map(int.tryParse).toList();
  if (digits.any((d) => d == null)) return null;
  final d = digits.cast<int>();

  final buf = StringBuffer('101');
  for (int i = 0; i < 4; i++) buf.write(_eanLeft_A[d[i]]);
  buf.write('01010');
  for (int i = 4; i < 8; i++) buf.write(_eanRight[d[i]]);
  buf.write('101');
  return buf.toString();
}

/// The family used for a barcode's human-readable value, when the host has
/// declared one it bundles.
String? get _readableFamily =>
    FontRegistry.bundledFamilies.isEmpty ? null : FontRegistry.bundledFamilies.first;

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

    final format = detectBarcodeFormat(el.content);
    String? binary;
    if (format == 'ean13') {
      binary = _encodeEan13(el.content);
    } else if (format == 'ean8') {
      binary = _encodeEan8(el.content);
    } else if (format == 'upca') {
      // UPC-A is EAN-13 with a leading '0'
      binary = _encodeEan13('0${el.content}');
    } else {
      binary = _encode128B(el.content);
    }

    // QR is drawn for real, from the same encoder the PDF painter uses. It
    // used to be a decorative placeholder here while the PDF fetched a PNG
    // from api.qrserver.com, so the canvas and the printed label showed two
    // different things and neither was the actual code.
    if (format == 'qr') {
      QrPainter(data: el.content, color: _parseColor(el.color) ?? Colors.black)
          .paint(canvas, size);
      return;
    }

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

    // Draw each *run* of dark modules as one rectangle, at exact coordinates.
    //
    // Drawing module-by-module with floor/ceil rounding — which is what this
    // did — merges the whole symbol into solid blocks as soon as a module is
    // narrower than a pixel: every bar is widened to a full pixel and snapped
    // left, so neighbours overlap. A 13-character Code 128 on a 50 mm label is
    // already under 1 px per module, so the shelf label of any shop using long
    // SKUs printed an unscannable black smear. Runs at true float widths keep
    // the ratios the symbology depends on.
    var i = 0;
    while (i < binary.length) {
      if (binary[i] != '1') {
        i++;
        continue;
      }
      final start = i;
      while (i < binary.length && binary[i] == '1') {
        i++;
      }
      canvas.drawRect(
        Rect.fromLTWH(start * barWidth, 2, (i - start) * barWidth, barH),
        barPaint,
      );
    }

    if (el.displayValue) {
      final tp = TextPainter(
        text: TextSpan(
          text: el.content,
          // Named explicitly. A bare TextStyle leans on the platform default,
          // which is how the human-readable value under a barcode ended up as
          // tofu boxes in an environment with no system font — the one piece
          // of a label a human reads when the scanner will not.
          style: TextStyle(
            fontFamily: _readableFamily,
            fontSize: 10,
            color: barColor,
          ),
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
