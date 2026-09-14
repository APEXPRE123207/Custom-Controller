import 'package:flutter_test/flutter_test.dart';
import 'package:nintendo_pro_controller/models/controller_protocol.dart';

void main() {
  group('Controller Protocol Tests', () {
    test('State serialization and deserialization integrity', () {
      final state = ControllerState();
      state.setButton(ControllerButton.a, true);
      state.setButton(ControllerButton.zl, true);
      state.setButton(ControllerButton.dpadUp, true);
      state.leftStickX = -0.75;
      state.leftStickY = 0.50;
      state.rightStickX = 0.25;
      state.rightStickY = -0.90;

      final bytes = state.toBytes(42, 0x1234);

      expect(bytes.length, 14);
      expect(bytes[0], 0x53); // 'S'
      expect(bytes[1], 0x57); // 'W'
      expect(bytes[2], PacketType.inputState);
      expect(bytes[3], 42); // Sequence

      final decoded = ControllerState.fromBytes(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.isPressed(ControllerButton.a), isTrue);
      expect(decoded.isPressed(ControllerButton.zl), isTrue);
      expect(decoded.isPressed(ControllerButton.dpadUp), isTrue);
      expect(decoded.isPressed(ControllerButton.b), isFalse);

      expect(decoded.leftStickX, closeTo(-0.75, 0.02));
      expect(decoded.leftStickY, closeTo(0.50, 0.02));
      expect(decoded.rightStickX, closeTo(0.25, 0.02));
      expect(decoded.rightStickY, closeTo(-0.90, 0.02));
    });

    test('Button bitmask uniqueness', () {
      final buttons = [
        ControllerButton.a,
        ControllerButton.b,
        ControllerButton.x,
        ControllerButton.y,
        ControllerButton.dpadUp,
        ControllerButton.dpadDown,
        ControllerButton.dpadLeft,
        ControllerButton.dpadRight,
        ControllerButton.l,
        ControllerButton.r,
        ControllerButton.zl,
        ControllerButton.zr,
        ControllerButton.plus,
        ControllerButton.minus,
        ControllerButton.lStickBtn,
        ControllerButton.rStickBtn,
        ControllerButton.home,
        ControllerButton.capture,
      ];

      final set = buttons.toSet();
      expect(set.length, buttons.length, reason: 'All button masks must be unique powers of 2');
    });
  });
}
