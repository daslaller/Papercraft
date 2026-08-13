import 'dart:convert';

import 'package:flutter/painting.dart' show BorderRadius, Radius;

import 'gradient_def.dart';
import 'table_element.dart';

export 'table_element.dart' show TableColumn, TableElement;

int _counter = 0;

String generateId() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return 'el_${ts}_${_counter++}';
}

/// Corner radius: uniform [borderRadius] and optional per-corner overrides.
///
/// When all four corner fields are null, [borderRadius] applies to every corner
/// (linked / uniform mode). When any corner is set, that value is used for that
/// corner and unset corners fall back to [borderRadius].
class CornerRadii {
  final double borderRadius;
  final double? borderRadiusTL;
  final double? borderRadiusTR;
  final double? borderRadiusBR;
  final double? borderRadiusBL;

  const CornerRadii({
    this.borderRadius = 0,
    this.borderRadiusTL,
    this.borderRadiusTR,
    this.borderRadiusBR,
    this.borderRadiusBL,
  });

  bool get isUniform =>
      borderRadiusTL == null &&
      borderRadiusTR == null &&
      borderRadiusBR == null &&
      borderRadiusBL == null;

  double get topLeft => borderRadiusTL ?? borderRadius;
  double get topRight => borderRadiusTR ?? borderRadius;
  double get bottomRight => borderRadiusBR ?? borderRadius;
  double get bottomLeft => borderRadiusBL ?? borderRadius;

  BorderRadius toBorderRadius() {
    if (isUniform) return BorderRadius.circular(borderRadius);
    return BorderRadius.only(
      topLeft: Radius.circular(topLeft),
      topRight: Radius.circular(topRight),
      bottomRight: Radius.circular(bottomRight),
      bottomLeft: Radius.circular(bottomLeft),
    );
  }

  /// Linked mode: all corners use [uniform], per-corner overrides cleared.
  CornerRadii asUniform(double uniform) => CornerRadii(borderRadius: uniform);

  /// Unlinked mode: initialize each corner from current resolved values.
  CornerRadii asUnlinked() => CornerRadii(
        borderRadius: borderRadius,
        borderRadiusTL: topLeft,
        borderRadiusTR: topRight,
        borderRadiusBR: bottomRight,
        borderRadiusBL: bottomLeft,
      );

  CornerRadii copyWith({
    double? borderRadius,
    double? borderRadiusTL,
    double? borderRadiusTR,
    double? borderRadiusBR,
    double? borderRadiusBL,
    bool clearCorners = false,
  }) =>
      CornerRadii(
        borderRadius: borderRadius ?? this.borderRadius,
        borderRadiusTL: clearCorners ? null : (borderRadiusTL ?? this.borderRadiusTL),
        borderRadiusTR: clearCorners ? null : (borderRadiusTR ?? this.borderRadiusTR),
        borderRadiusBR: clearCorners ? null : (borderRadiusBR ?? this.borderRadiusBR),
        borderRadiusBL: clearCorners ? null : (borderRadiusBL ?? this.borderRadiusBL),
      );

  Map<String, dynamic> toJsonFields() => {
        'borderRadius': borderRadius,
        if (borderRadiusTL != null) 'borderRadiusTL': borderRadiusTL,
        if (borderRadiusTR != null) 'borderRadiusTR': borderRadiusTR,
        if (borderRadiusBR != null) 'borderRadiusBR': borderRadiusBR,
        if (borderRadiusBL != null) 'borderRadiusBL': borderRadiusBL,
      };

  factory CornerRadii.fromJson(Map<String, dynamic> j, {double defaultRadius = 0}) =>
      CornerRadii(
        borderRadius: (j['borderRadius'] as num? ?? defaultRadius).toDouble(),
        borderRadiusTL: (j['borderRadiusTL'] as num?)?.toDouble(),
        borderRadiusTR: (j['borderRadiusTR'] as num?)?.toDouble(),
        borderRadiusBR: (j['borderRadiusBR'] as num?)?.toDouble(),
        borderRadiusBL: (j['borderRadiusBL'] as num?)?.toDouble(),
      );
}

// ── Flex child base ──────────────────────────────────────────────────────────

abstract class CanvasElement {
  String get id;
  String get type;
  double? get x;
  double? get y;
  double? get width;
  double? get height;
  double get rotation;
  double get opacity;
  int get zIndex;
  bool get isSection;

  Map<String, dynamic> toJson();

  static CanvasElement fromJson(Map<String, dynamic> j) {
    switch (j['type'] as String) {
      case 'text':
        return TextElement.fromJson(j);
      case 'shape':
        return ShapeElement.fromJson(j);
      case 'image':
        return ImageElement.fromJson(j);
      case 'qr':
        return QrElement.fromJson(j);
      case 'barcode':
        return BarcodeElement.fromJson(j);
      case 'row':
      case 'col':
        return ContainerElement.fromJson(j);
      case 'table':
        return TableElement.fromJson(j);
      default:
        throw ArgumentError('Unknown element type: ${j['type']}');
    }
  }
}

// ── Text Element ─────────────────────────────────────────────────────────────

class TextElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type = 'text';
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;
  @override
  final bool isSection = false;

  final String content;
  final double fontSize;
  final String fontFamily;
  final String fontWeight;
  final String fontStyle;
  final String textAlign;
  final String color;
  final double lineHeight;
  final GradientDef? textGradient;
  final String? boxShadow;
  final double? letterSpacing;
  final String? textDecoration; // 'underline' | 'lineThrough' | 'overline' | null

  // Flex child props (null when absolute)
  final int? flex;
  final String? alignSelf;

  const TextElement({
    required this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.content = 'Double-click to edit',
    this.fontSize = 16,
    this.fontFamily = 'Inter',
    this.fontWeight = 'normal',
    this.fontStyle = 'normal',
    this.textAlign = 'left',
    this.color = '#1A1A1A',
    this.lineHeight = 1.4,
    this.textGradient,
    this.boxShadow,
    this.letterSpacing,
    this.textDecoration,
    this.flex,
    this.alignSelf,
  });

  static TextElement create({
    double x = 20,
    double y = 20,
    double width = 200,
    double height = 60,
    String content = 'Double-click to edit',
  }) =>
      TextElement(
        id: generateId(),
        x: x,
        y: y,
        width: width,
        height: height,
        content: content,
      );

  static TextElement createChild({String content = 'Text'}) => TextElement(
        id: generateId(),
        flex: 0,
        alignSelf: 'auto',
        content: content,
        fontSize: 14,
      );

  TextElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    String? content,
    double? fontSize,
    String? fontFamily,
    String? fontWeight,
    String? fontStyle,
    String? textAlign,
    String? color,
    double? lineHeight,
    GradientDef? textGradient,
    bool clearGradient = false,
    String? boxShadow,
    bool clearShadow = false,
    double? letterSpacing,
    bool clearLetterSpacing = false,
    String? textDecoration,
    bool clearDecoration = false,
    int? flex,
    String? alignSelf,
  }) =>
      TextElement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        content: content ?? this.content,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        fontWeight: fontWeight ?? this.fontWeight,
        fontStyle: fontStyle ?? this.fontStyle,
        textAlign: textAlign ?? this.textAlign,
        color: color ?? this.color,
        lineHeight: lineHeight ?? this.lineHeight,
        textGradient: clearGradient ? null : (textGradient ?? this.textGradient),
        boxShadow: clearShadow ? null : (boxShadow ?? this.boxShadow),
        letterSpacing: clearLetterSpacing ? null : (letterSpacing ?? this.letterSpacing),
        textDecoration: clearDecoration ? null : (textDecoration ?? this.textDecoration),
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'content': content,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'fontWeight': fontWeight,
        'fontStyle': fontStyle,
        'textAlign': textAlign,
        'color': color,
        'lineHeight': lineHeight,
        if (textGradient != null) 'textGradient': textGradient!.toJson(),
        if (boxShadow != null) 'boxShadow': boxShadow,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        if (textDecoration != null) 'textDecoration': textDecoration,
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory TextElement.fromJson(Map<String, dynamic> j) => TextElement(
        id: j['id'] as String,
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        rotation: (j['rotation'] as num? ?? 0).toDouble(),
        opacity: (j['opacity'] as num? ?? 1).toDouble(),
        zIndex: (j['zIndex'] as int? ?? 1),
        content: j['content'] as String? ?? '',
        fontSize: (j['fontSize'] as num? ?? 16).toDouble(),
        fontFamily: j['fontFamily'] as String? ?? 'Inter',
        fontWeight: j['fontWeight'] as String? ?? 'normal',
        fontStyle: j['fontStyle'] as String? ?? 'normal',
        textAlign: j['textAlign'] as String? ?? 'left',
        color: j['color'] as String? ?? '#1A1A1A',
        lineHeight: (j['lineHeight'] as num? ?? 1.4).toDouble(),
        textGradient: j['textGradient'] != null
            ? GradientDef.fromJson(j['textGradient'] as Map<String, dynamic>)
            : null,
        boxShadow: j['boxShadow'] as String?,
        letterSpacing: (j['letterSpacing'] as num?)?.toDouble(),
        textDecoration: j['textDecoration'] as String?,
        flex: j['flex'] as int?,
        alignSelf: j['alignSelf'] as String?,
      );
}

// ── Shape Element ─────────────────────────────────────────────────────────────

class ShapeElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type = 'shape';
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;
  @override
  final bool isSection = false;

  final String shape; // 'rectangle' | 'circle' | 'line'
  final String fill;
  final String stroke;
  final double strokeWidth;
  final double borderRadius;
  final double? borderRadiusTL;
  final double? borderRadiusTR;
  final double? borderRadiusBR;
  final double? borderRadiusBL;
  final GradientDef? gradient;
  final String? boxShadow;

  final int? flex;
  final String? alignSelf;

  const ShapeElement({
    required this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.shape = 'rectangle',
    this.fill = '#E8E6E1',
    this.stroke = '#1A1A1A',
    this.strokeWidth = 1,
    this.borderRadius = 4,
    this.borderRadiusTL,
    this.borderRadiusTR,
    this.borderRadiusBR,
    this.borderRadiusBL,
    this.gradient,
    this.boxShadow,
    this.flex,
    this.alignSelf,
  });

  CornerRadii get corners => CornerRadii(
        borderRadius: borderRadius,
        borderRadiusTL: borderRadiusTL,
        borderRadiusTR: borderRadiusTR,
        borderRadiusBR: borderRadiusBR,
        borderRadiusBL: borderRadiusBL,
      );

  static ShapeElement create(String shape) => ShapeElement(
        id: generateId(),
        x: 40,
        y: 40,
        width: shape == 'line' ? 120 : 120,
        height: shape == 'line' ? 2 : 80,
        shape: shape,
        borderRadius: shape == 'circle' ? 50 : 4,
      );

  static ShapeElement createChild(String shape) => ShapeElement(
        id: generateId(),
        flex: 0,
        alignSelf: 'auto',
        width: 60,
        height: 40,
        shape: shape,
        borderRadius: shape == 'circle' ? 50 : 4,
      );

  ShapeElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    String? shape,
    String? fill,
    String? stroke,
    double? strokeWidth,
    double? borderRadius,
    double? borderRadiusTL,
    double? borderRadiusTR,
    double? borderRadiusBR,
    double? borderRadiusBL,
    bool clearCornerRadii = false,
    GradientDef? gradient,
    bool clearGradient = false,
    String? boxShadow,
    bool clearShadow = false,
    int? flex,
    String? alignSelf,
  }) =>
      ShapeElement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        shape: shape ?? this.shape,
        fill: fill ?? this.fill,
        stroke: stroke ?? this.stroke,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        borderRadius: borderRadius ?? this.borderRadius,
        borderRadiusTL: clearCornerRadii ? null : (borderRadiusTL ?? this.borderRadiusTL),
        borderRadiusTR: clearCornerRadii ? null : (borderRadiusTR ?? this.borderRadiusTR),
        borderRadiusBR: clearCornerRadii ? null : (borderRadiusBR ?? this.borderRadiusBR),
        borderRadiusBL: clearCornerRadii ? null : (borderRadiusBL ?? this.borderRadiusBL),
        gradient: clearGradient ? null : (gradient ?? this.gradient),
        boxShadow: clearShadow ? null : (boxShadow ?? this.boxShadow),
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'shape': shape,
        'fill': fill,
        'stroke': stroke,
        'strokeWidth': strokeWidth,
        ...corners.toJsonFields(),
        if (gradient != null) 'gradient': gradient!.toJson(),
        if (boxShadow != null) 'boxShadow': boxShadow,
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory ShapeElement.fromJson(Map<String, dynamic> j) {
    final c = CornerRadii.fromJson(j, defaultRadius: 4);
    return ShapeElement(
      id: j['id'] as String,
      x: (j['x'] as num?)?.toDouble(),
      y: (j['y'] as num?)?.toDouble(),
      width: (j['width'] as num?)?.toDouble(),
      height: (j['height'] as num?)?.toDouble(),
      rotation: (j['rotation'] as num? ?? 0).toDouble(),
      opacity: (j['opacity'] as num? ?? 1).toDouble(),
      zIndex: (j['zIndex'] as int? ?? 1),
      shape: j['shape'] as String? ?? 'rectangle',
      fill: j['fill'] as String? ?? '#E8E6E1',
      stroke: j['stroke'] as String? ?? '#1A1A1A',
      strokeWidth: (j['strokeWidth'] as num? ?? 1).toDouble(),
      borderRadius: c.borderRadius,
      borderRadiusTL: c.borderRadiusTL,
      borderRadiusTR: c.borderRadiusTR,
      borderRadiusBR: c.borderRadiusBR,
      borderRadiusBL: c.borderRadiusBL,
      gradient: j['gradient'] != null
          ? GradientDef.fromJson(j['gradient'] as Map<String, dynamic>)
          : null,
      boxShadow: j['boxShadow'] as String?,
      flex: j['flex'] as int?,
      alignSelf: j['alignSelf'] as String?,
    );
  }
}

// ── Image Element ────────────────────────────────────────────────────────────

class ImageElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type = 'image';
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;
  @override
  final bool isSection = false;

  final String src;
  final String objectFit;
  final double borderRadius;
  final double? borderRadiusTL;
  final double? borderRadiusTR;
  final double? borderRadiusBR;
  final double? borderRadiusBL;
  final String? boxShadow;

  final int? flex;
  final String? alignSelf;

  const ImageElement({
    required this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.src = '',
    this.objectFit = 'cover',
    this.borderRadius = 0,
    this.borderRadiusTL,
    this.borderRadiusTR,
    this.borderRadiusBR,
    this.borderRadiusBL,
    this.boxShadow,
    this.flex,
    this.alignSelf,
  });

  CornerRadii get corners => CornerRadii(
        borderRadius: borderRadius,
        borderRadiusTL: borderRadiusTL,
        borderRadiusTR: borderRadiusTR,
        borderRadiusBR: borderRadiusBR,
        borderRadiusBL: borderRadiusBL,
      );

  static ImageElement create() => ImageElement(
        id: generateId(),
        x: 40,
        y: 40,
        width: 150,
        height: 100,
      );

  static ImageElement createChild() => ImageElement(
        id: generateId(),
        flex: 0,
        alignSelf: 'auto',
        width: 80,
        height: 60,
      );

  ImageElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    String? src,
    String? objectFit,
    double? borderRadius,
    double? borderRadiusTL,
    double? borderRadiusTR,
    double? borderRadiusBR,
    double? borderRadiusBL,
    bool clearCornerRadii = false,
    String? boxShadow,
    bool clearShadow = false,
    int? flex,
    String? alignSelf,
  }) =>
      ImageElement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        src: src ?? this.src,
        objectFit: objectFit ?? this.objectFit,
        borderRadius: borderRadius ?? this.borderRadius,
        borderRadiusTL: clearCornerRadii ? null : (borderRadiusTL ?? this.borderRadiusTL),
        borderRadiusTR: clearCornerRadii ? null : (borderRadiusTR ?? this.borderRadiusTR),
        borderRadiusBR: clearCornerRadii ? null : (borderRadiusBR ?? this.borderRadiusBR),
        borderRadiusBL: clearCornerRadii ? null : (borderRadiusBL ?? this.borderRadiusBL),
        boxShadow: clearShadow ? null : (boxShadow ?? this.boxShadow),
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'src': src,
        'objectFit': objectFit,
        ...corners.toJsonFields(),
        if (boxShadow != null) 'boxShadow': boxShadow,
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory ImageElement.fromJson(Map<String, dynamic> j) {
    final c = CornerRadii.fromJson(j);
    return ImageElement(
      id: j['id'] as String,
      x: (j['x'] as num?)?.toDouble(),
      y: (j['y'] as num?)?.toDouble(),
      width: (j['width'] as num?)?.toDouble(),
      height: (j['height'] as num?)?.toDouble(),
      rotation: (j['rotation'] as num? ?? 0).toDouble(),
      opacity: (j['opacity'] as num? ?? 1).toDouble(),
      zIndex: (j['zIndex'] as int? ?? 1),
      src: j['src'] as String? ?? '',
      objectFit: j['objectFit'] as String? ?? 'cover',
      borderRadius: c.borderRadius,
      borderRadiusTL: c.borderRadiusTL,
      borderRadiusTR: c.borderRadiusTR,
      borderRadiusBR: c.borderRadiusBR,
      borderRadiusBL: c.borderRadiusBL,
      boxShadow: j['boxShadow'] as String?,
      flex: j['flex'] as int?,
      alignSelf: j['alignSelf'] as String?,
    );
  }
}

// ── QR Element ───────────────────────────────────────────────────────────────

class QrElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type = 'qr';
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;
  @override
  final bool isSection = false;

  final String content;
  final int? flex;
  final String? alignSelf;

  const QrElement({
    required this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.content = 'https://example.com',
    this.flex,
    this.alignSelf,
  });

  static QrElement create() => QrElement(
        id: generateId(),
        x: 40,
        y: 40,
        width: 80,
        height: 80,
      );

  static QrElement createChild() => QrElement(
        id: generateId(),
        flex: 0,
        alignSelf: 'auto',
        width: 60,
        height: 60,
      );

  QrElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    String? content,
    int? flex,
    String? alignSelf,
  }) =>
      QrElement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        content: content ?? this.content,
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'content': content,
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory QrElement.fromJson(Map<String, dynamic> j) => QrElement(
        id: j['id'] as String,
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        rotation: (j['rotation'] as num? ?? 0).toDouble(),
        opacity: (j['opacity'] as num? ?? 1).toDouble(),
        zIndex: (j['zIndex'] as int? ?? 1),
        content: j['content'] as String? ?? 'https://example.com',
        flex: j['flex'] as int?,
        alignSelf: j['alignSelf'] as String?,
      );
}

// ── Barcode Element ──────────────────────────────────────────────────────────

class BarcodeElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type = 'barcode';
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;
  @override
  final bool isSection = false;

  final String content;
  final String format;
  final bool displayValue;
  final String color;
  final String background;
  final int? flex;
  final String? alignSelf;

  const BarcodeElement({
    required this.id,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.content = '1234567890',
    this.format = 'CODE128',
    this.displayValue = true,
    this.color = '#000000',
    this.background = '#ffffff',
    this.flex,
    this.alignSelf,
  });

  static BarcodeElement create() => BarcodeElement(
        id: generateId(),
        x: 40,
        y: 40,
        width: 200,
        height: 80,
      );

  static BarcodeElement createChild() => BarcodeElement(
        id: generateId(),
        flex: 0,
        alignSelf: 'auto',
        width: 160,
        height: 60,
      );

  BarcodeElement copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    String? content,
    String? format,
    bool? displayValue,
    String? color,
    String? background,
    int? flex,
    String? alignSelf,
  }) =>
      BarcodeElement(
        id: id,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        content: content ?? this.content,
        format: format ?? this.format,
        displayValue: displayValue ?? this.displayValue,
        color: color ?? this.color,
        background: background ?? this.background,
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'content': content,
        'format': format,
        'displayValue': displayValue,
        'color': color,
        'background': background,
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory BarcodeElement.fromJson(Map<String, dynamic> j) => BarcodeElement(
        id: j['id'] as String,
        x: (j['x'] as num?)?.toDouble(),
        y: (j['y'] as num?)?.toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
        rotation: (j['rotation'] as num? ?? 0).toDouble(),
        opacity: (j['opacity'] as num? ?? 1).toDouble(),
        zIndex: (j['zIndex'] as int? ?? 1),
        content: j['content'] as String? ?? '1234567890',
        format: j['format'] as String? ?? 'CODE128',
        displayValue: j['displayValue'] as bool? ?? true,
        color: j['color'] as String? ?? '#000000',
        background: j['background'] as String? ?? '#ffffff',
        flex: j['flex'] as int?,
        alignSelf: j['alignSelf'] as String?,
      );
}

// ── Container Element (Row/Col) ───────────────────────────────────────────────

class ContainerElement implements CanvasElement {
  @override
  final String id;
  @override
  final String type; // 'row' | 'col'
  @override
  final double? x;
  @override
  final double? y;
  @override
  final double? width;
  @override
  final double? height;
  @override
  final double rotation;
  @override
  final double opacity;
  @override
  final int zIndex;
  @override
  final bool isSection;

  final double minHeight;
  final double gap;
  final double padding;

  /// Horizontal and vertical padding overrides.
  ///
  /// [padding] is a single `EdgeInsets.all` value, which cannot express the
  /// asymmetric page margins every real document has — a 40 px gutter down
  /// both sides with a different gap above and below. These fall back to
  /// [padding] when unset, so existing templates are unaffected.
  final double? paddingX;
  final double? paddingY;
  final String alignItems;
  final bool freePlacement; // true = Stack, false = Row/Col flex
  final String background;
  final GradientDef? gradient;
  final double borderRadius;
  final double? borderRadiusTL;
  final double? borderRadiusTR;
  final double? borderRadiusBR;
  final double? borderRadiusBL;
  final String? boxShadow;
  final bool locked;
  final List<CanvasElement> children;

  // Flex child props
  final int? flex;
  final String? alignSelf;

  const ContainerElement({
    required this.id,
    required this.type,
    this.x,
    this.y,
    this.width,
    this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.zIndex = 1,
    this.isSection = false,
    this.minHeight = 60,
    this.gap = 8,
    this.padding = 8,
    this.paddingX,
    this.paddingY,
    this.alignItems = 'flex-start',
    this.freePlacement = false,
    this.background = 'transparent',
    this.gradient,
    this.borderRadius = 0,
    this.borderRadiusTL,
    this.borderRadiusTR,
    this.borderRadiusBR,
    this.borderRadiusBL,
    this.boxShadow,
    this.locked = false,
    this.children = const [],
    this.flex,
    this.alignSelf,
  });

  /// Effective horizontal padding — [paddingX] when set, else [padding].
  double get padX => paddingX ?? padding;

  /// Effective vertical padding — [paddingY] when set, else [padding].
  double get padY => paddingY ?? padding;

  CornerRadii get corners => CornerRadii(
        borderRadius: borderRadius,
        borderRadiusTL: borderRadiusTL,
        borderRadiusTR: borderRadiusTR,
        borderRadiusBR: borderRadiusBR,
        borderRadiusBL: borderRadiusBL,
      );

  static ContainerElement createSection(String type) => ContainerElement(
        id: generateId(),
        type: type,
        isSection: true,
        minHeight: 60,
        gap: 8,
        padding: 8,
        alignItems: type == 'row' ? 'center' : 'flex-start',
      );

  static ContainerElement createAbsolute(String type) => ContainerElement(
        id: generateId(),
        type: type,
        isSection: false,
        x: 40,
        y: 40,
        width: 200,
        height: 80,
        alignItems: type == 'row' ? 'center' : 'flex-start',
      );

  static ContainerElement createChild(String type) => ContainerElement(
        id: generateId(),
        type: type,
        // flex=1 lets this container participate in equal-width slicing when
        // it lives inside a Row parent. Null width/height lets the layout
        // engine (Expanded / Column stretch) determine the actual size.
        flex: 1,
        width: null,  // determined by Expanded in Row, or Column stretch
        height: type == 'row' ? 64 : null, // Row children need explicit height for Column parents
        gap: 8,
        padding: 8,
        alignItems: type == 'row' ? 'center' : 'flex-start',
      );

  ContainerElement copyWith({
    String? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    int? zIndex,
    bool? isSection,
    double? minHeight,
    double? gap,
    double? padding,
    double? paddingX,
    double? paddingY,
    String? alignItems,
    bool? freePlacement,
    String? background,
    GradientDef? gradient,
    bool clearGradient = false,
    double? borderRadius,
    double? borderRadiusTL,
    double? borderRadiusTR,
    double? borderRadiusBR,
    double? borderRadiusBL,
    bool clearCornerRadii = false,
    String? boxShadow,
    bool clearShadow = false,
    bool? locked,
    List<CanvasElement>? children,
    int? flex,
    String? alignSelf,
  }) =>
      ContainerElement(
        id: id,
        type: type ?? this.type,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        rotation: rotation ?? this.rotation,
        opacity: opacity ?? this.opacity,
        zIndex: zIndex ?? this.zIndex,
        isSection: isSection ?? this.isSection,
        minHeight: minHeight ?? this.minHeight,
        gap: gap ?? this.gap,
        padding: padding ?? this.padding,
        paddingX: paddingX ?? this.paddingX,
        paddingY: paddingY ?? this.paddingY,
        alignItems: alignItems ?? this.alignItems,
        freePlacement: freePlacement ?? this.freePlacement,
        background: background ?? this.background,
        gradient: clearGradient ? null : (gradient ?? this.gradient),
        borderRadius: borderRadius ?? this.borderRadius,
        borderRadiusTL: clearCornerRadii ? null : (borderRadiusTL ?? this.borderRadiusTL),
        borderRadiusTR: clearCornerRadii ? null : (borderRadiusTR ?? this.borderRadiusTR),
        borderRadiusBR: clearCornerRadii ? null : (borderRadiusBR ?? this.borderRadiusBR),
        borderRadiusBL: clearCornerRadii ? null : (borderRadiusBL ?? this.borderRadiusBL),
        boxShadow: clearShadow ? null : (boxShadow ?? this.boxShadow),
        locked: locked ?? this.locked,
        children: children ?? this.children,
        flex: flex ?? this.flex,
        alignSelf: alignSelf ?? this.alignSelf,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'rotation': rotation,
        'opacity': opacity,
        'zIndex': zIndex,
        'isSection': isSection,
        'minHeight': minHeight,
        'gap': gap,
        'padding': padding,
        if (paddingX != null) 'paddingX': paddingX,
        if (paddingY != null) 'paddingY': paddingY,
        'alignItems': alignItems,
        'freePlacement': freePlacement,
        'background': background,
        if (gradient != null) 'gradient': gradient!.toJson(),
        ...corners.toJsonFields(),
        if (boxShadow != null) 'boxShadow': boxShadow,
        'locked': locked,
        'children': children.map((c) => c.toJson()).toList(),
        if (flex != null) 'flex': flex,
        if (alignSelf != null) 'alignSelf': alignSelf,
      };

  factory ContainerElement.fromJson(Map<String, dynamic> j) {
    final c = CornerRadii.fromJson(j);
    return ContainerElement(
      id: j['id'] as String,
      type: j['type'] as String,
      x: (j['x'] as num?)?.toDouble(),
      y: (j['y'] as num?)?.toDouble(),
      width: (j['width'] as num?)?.toDouble(),
      height: (j['height'] as num?)?.toDouble(),
      rotation: (j['rotation'] as num? ?? 0).toDouble(),
      opacity: (j['opacity'] as num? ?? 1).toDouble(),
      zIndex: (j['zIndex'] as int? ?? 1),
      isSection: j['isSection'] as bool? ?? false,
      minHeight: (j['minHeight'] as num? ?? 60).toDouble(),
      gap: (j['gap'] as num? ?? 8).toDouble(),
      padding: (j['padding'] as num? ?? 8).toDouble(),
      paddingX: (j['paddingX'] as num?)?.toDouble(),
      paddingY: (j['paddingY'] as num?)?.toDouble(),
      alignItems: j['alignItems'] as String? ?? 'flex-start',
      freePlacement: j['freePlacement'] as bool? ?? false,
      background: j['background'] as String? ?? 'transparent',
      gradient: j['gradient'] != null
          ? GradientDef.fromJson(j['gradient'] as Map<String, dynamic>)
          : null,
      borderRadius: c.borderRadius,
      borderRadiusTL: c.borderRadiusTL,
      borderRadiusTR: c.borderRadiusTR,
      borderRadiusBR: c.borderRadiusBR,
      borderRadiusBL: c.borderRadiusBL,
      boxShadow: j['boxShadow'] as String?,
      locked: j['locked'] as bool? ?? false,
      children: j['children'] != null
          ? (j['children'] as List)
              .map((c) => CanvasElement.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
      flex: j['flex'] as int?,
      alignSelf: j['alignSelf'] as String?,
    );
  }
}

// ── Tree utilities ────────────────────────────────────────────────────────────

CanvasElement? findNodeInTree(List<CanvasElement> nodes, String nodeId) {
  for (final n in nodes) {
    if (n.id == nodeId) return n;
    if (n is ContainerElement) {
      final found = findNodeInTree(n.children, nodeId);
      if (found != null) return found;
    }
  }
  return null;
}

List<CanvasElement> updateNodeInTree(
    List<CanvasElement> nodes, String nodeId, CanvasElement updated) {
  return nodes.map((n) {
    if (n.id == nodeId) return updated;
    if (n is ContainerElement) {
      return n.copyWith(children: updateNodeInTree(n.children, nodeId, updated));
    }
    return n;
  }).toList();
}

List<CanvasElement> deleteNodeInTree(List<CanvasElement> nodes, String nodeId) {
  return nodes
      .where((n) => n.id != nodeId)
      .map((n) {
        if (n is ContainerElement) {
          return n.copyWith(children: deleteNodeInTree(n.children, nodeId));
        }
        return n;
      })
      .toList();
}

List<CanvasElement> addChildDeep(
    List<CanvasElement> nodes, String containerId, CanvasElement child) {
  return nodes.map((n) {
    if (n.id == containerId && n is ContainerElement) {
      return n.copyWith(children: [...n.children, child]);
    }
    if (n is ContainerElement) {
      return n.copyWith(children: addChildDeep(n.children, containerId, child));
    }
    return n;
  }).toList();
}

List<CanvasElement> elementsFromJson(String json) {
  final list = jsonDecode(json) as List;
  return list.map((j) => CanvasElement.fromJson(j as Map<String, dynamic>)).toList();
}

String elementsToJson(List<CanvasElement> elements) =>
    jsonEncode(elements.map((e) => e.toJson()).toList());
