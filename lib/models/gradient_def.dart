import 'dart:math' as math;
import 'package:flutter/material.dart';

class GradientStop {
  final String color;
  final double pos; // 0–100

  const GradientStop({required this.color, required this.pos});

  factory GradientStop.fromJson(Map<String, dynamic> j) =>
      GradientStop(color: j['color'] as String, pos: (j['pos'] as num).toDouble());

  Map<String, dynamic> toJson() => {'color': color, 'pos': pos};

  Color get flutterColor {
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class GradientDef {
  final String type; // 'linear' | 'radial'
  final double angle;
  final List<GradientStop> stops;

  const GradientDef({
    required this.type,
    this.angle = 90,
    required this.stops,
  });

  factory GradientDef.fromJson(Map<String, dynamic> j) => GradientDef(
        type: j['type'] as String,
        angle: (j['angle'] as num? ?? 90).toDouble(),
        stops: (j['stops'] as List)
            .map((s) => GradientStop.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  GradientDef copyWith({
    String? type,
    double? angle,
    List<GradientStop>? stops,
  }) =>
      GradientDef(
        type: type ?? this.type,
        angle: angle ?? this.angle,
        stops: stops ?? this.stops,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'angle': angle,
        'stops': stops.map((s) => s.toJson()).toList(),
      };

  static GradientDef get defaultGradient => const GradientDef(
        type: 'linear',
        angle: 90,
        stops: [
          GradientStop(color: '#6366f1', pos: 0),
          GradientStop(color: '#ec4899', pos: 100),
        ],
      );

  Gradient toFlutter() {
    final sorted = [...stops]..sort((a, b) => a.pos.compareTo(b.pos));
    final colors = sorted.map((s) => s.flutterColor).toList();
    final colorStops = sorted.map((s) => s.pos / 100).toList();

    if (type == 'radial') {
      return RadialGradient(colors: colors, stops: colorStops);
    }
    // Convert angle degrees to Flutter alignment
    final rad = (angle - 90) * math.pi / 180;
    final begin = Alignment(-math.sin(rad), -math.cos(rad));
    final end = Alignment(math.sin(rad), math.cos(rad));
    return LinearGradient(colors: colors, stops: colorStops, begin: begin, end: end);
  }
}
