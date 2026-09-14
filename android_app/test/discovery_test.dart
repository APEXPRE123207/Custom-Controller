import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Discovery packet parsing', () {
    // [83, 87, 8, 0, 195, 34, 210, 4, 0, 0, 9, 71, 97, 109, 105, 110, 103, 45, 80, 67]
    final bytes = Uint8List.fromList([
      0x53, 0x57, 0x08, 0x00,
      0xC3, 0x22, // 8899
      0xD2, 0x04, 0x00, 0x00, // 1234
      0x09, // len
      0x47, 0x61, 0x6D, 0x69, 0x6E, 0x67, 0x2D, 0x50, 0x43, // Gaming-PC
    ]);

    final view = ByteData.view(bytes.buffer);
    expect(bytes[0], 0x53);
    expect(bytes[1], 0x57);
    expect(bytes[2], 0x08);

    final port = view.getUint16(4, Endian.little);
    final pin = view.getUint32(6, Endian.little);
    final nameLen = bytes[10];
    final name = String.fromCharCodes(bytes.sublist(11, 11 + nameLen));

    expect(port, 8899);
    expect(pin, 1234);
    expect(name, 'Gaming-PC');
  });
}
