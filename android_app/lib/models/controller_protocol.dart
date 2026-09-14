import 'dart:typed_data';

/// Button bitmask flags matching Nintendo Switch Pro Controller inputs.
class ControllerButton {
  static const int a = 1 << 0; // 'Z' in Ryujinx
  static const int b = 1 << 1; // 'X' in Ryujinx
  static const int x = 1 << 2; // 'C' in Ryujinx
  static const int y = 1 << 3; // 'V' in Ryujinx
  static const int dpadUp = 1 << 4; // Up Arrow
  static const int dpadDown = 1 << 5; // Down Arrow
  static const int dpadLeft = 1 << 6; // Left Arrow
  static const int dpadRight = 1 << 7; // Right Arrow
  static const int l = 1 << 8; // 'E'
  static const int r = 1 << 9; // 'U'
  static const int zl = 1 << 10; // 'Q'
  static const int zr = 1 << 11; // 'O'
  static const int plus = 1 << 12; // Plus key '='
  static const int minus = 1 << 13; // Minus key '-'
  static const int lStickBtn = 1 << 14; // 'F' (L3)
  static const int rStickBtn = 1 << 15; // 'H' (R3)
  static const int home = 1 << 16; // Home
  static const int capture = 1 << 17; // Screenshot / F12
}

/// Message types for the binary protocol
class PacketType {
  static const int authRequest = 1;
  static const int authSuccess = 2;
  static const int authFailed = 3;
  static const int inputState = 4;
  static const int ping = 5;
  static const int pong = 6;
  static const int discover = 7;
  static const int discoverReply = 8;
}

/// High-efficiency, ultra-low latency controller state snapshot.
class ControllerState {
  int buttons = 0;
  double leftStickX = 0.0; // -1.0 to 1.0
  double leftStickY = 0.0; // -1.0 to 1.0
  double rightStickX = 0.0; // -1.0 to 1.0
  double rightStickY = 0.0; // -1.0 to 1.0

  ControllerState();

  void setButton(int buttonMask, bool pressed) {
    if (pressed) {
      buttons |= buttonMask;
    } else {
      buttons &= ~buttonMask;
    }
  }

  bool isPressed(int buttonMask) => (buttons & buttonMask) != 0;

  /// Serializes the state into a fixed 14-byte binary packet
  Uint8List toBytes(int sequence, int sessionToken) {
    final buffer = Uint8List(14);
    final view = ByteData.view(buffer.buffer);

    // Magic Header 'SW'
    buffer[0] = 0x53; // 'S'
    buffer[1] = 0x57; // 'W'

    // Packet type: inputState
    buffer[2] = PacketType.inputState;

    // Sequence (0..255)
    buffer[3] = sequence & 0xFF;

    // Button bitmask (32-bit little endian)
    view.setUint32(4, buttons, Endian.little);

    // Sticks converted to signed int8 (-127 to 127)
    buffer[8] = (leftStickX.clamp(-1.0, 1.0) * 127).round().toSigned(8);
    buffer[9] = (leftStickY.clamp(-1.0, 1.0) * 127).round().toSigned(8);
    buffer[10] = (rightStickX.clamp(-1.0, 1.0) * 127).round().toSigned(8);
    buffer[11] = (rightStickY.clamp(-1.0, 1.0) * 127).round().toSigned(8);

    // Session token (16-bit uint)
    view.setUint16(12, sessionToken & 0xFFFF, Endian.little);

    return buffer;
  }

  /// Deserializes a 14-byte packet
  static ControllerState? fromBytes(Uint8List bytes) {
    if (bytes.length < 14) return null;
    if (bytes[0] != 0x53 || bytes[1] != 0x57) return null; // Magic check

    final view = ByteData.view(bytes.buffer);
    final state = ControllerState();
    state.buttons = view.getUint32(4, Endian.little);

    state.leftStickX = (view.getInt8(8) / 127.0).clamp(-1.0, 1.0);
    state.leftStickY = (view.getInt8(9) / 127.0).clamp(-1.0, 1.0);
    state.rightStickX = (view.getInt8(10) / 127.0).clamp(-1.0, 1.0);
    state.rightStickY = (view.getInt8(11) / 127.0).clamp(-1.0, 1.0);

    return state;
  }
}
