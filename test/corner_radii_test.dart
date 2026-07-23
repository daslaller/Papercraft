import 'package:papercraft/models/element_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CornerRadii', () {
    test('uniform mode uses circular radius', () {
      const c = CornerRadii(borderRadius: 8);
      expect(c.isUniform, isTrue);
      expect(c.toBorderRadius(), BorderRadius.circular(8));
    });

    test('per-corner overrides fall back to borderRadius', () {
      const c = CornerRadii(
        borderRadius: 4,
        borderRadiusTL: 12,
        borderRadiusBR: 2,
      );
      expect(c.isUniform, isFalse);
      expect(c.topLeft, 12);
      expect(c.topRight, 4);
      expect(c.bottomRight, 2);
      expect(c.bottomLeft, 4);
    });

    test('ShapeElement serializes and restores corners', () {
      final el = ShapeElement(
        id: 's1',
        borderRadius: 6,
        borderRadiusTL: 10,
        borderRadiusTR: 2,
      );
      final restored = ShapeElement.fromJson(el.toJson());
      expect(restored.borderRadius, 6);
      expect(restored.borderRadiusTL, 10);
      expect(restored.borderRadiusTR, 2);
      expect(restored.borderRadiusBR, isNull);
    });

    test('legacy JSON without per-corner fields stays uniform', () {
      final el = ShapeElement.fromJson({
        'id': 'legacy',
        'type': 'shape',
        'borderRadius': 5,
      });
      expect(el.corners.isUniform, isTrue);
      expect(el.borderRadius, 5);
    });
  });
}
