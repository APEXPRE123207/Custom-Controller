import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/controller_protocol.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  authenticating,
  connected,
  failed,
}

enum TransportType {
  wifiUdp,
  bluetooth,
}

/// Manages dual-mode communication (Bluetooth / Wi-Fi UDP) with the desktop receiver.
class ConnectionService extends ChangeNotifier {
  static final ConnectionService instance = ConnectionService._internal();
  ConnectionService._internal();

  ConnectionStatus status = ConnectionStatus.disconnected;
  TransportType currentTransport = TransportType.wifiUdp;

  String? serverAddress;
  int serverPort = 8899;
  String currentPin = "1234";

  int sessionToken = 0;
  int _sequence = 0;
  int currentLatencyMs = 0;
  String? errorMessage;

  RawDatagramSocket? _udpSocket;
  Timer? _heartbeatTimer;
  DateTime? _lastPingSent;
  int _lastSentButtons = 0;
  double _lastLStickX = 0;
  double _lastLStickY = 0;
  double _lastRStickX = 0;
  double _lastRStickY = 0;

  bool get isConnected => status == ConnectionStatus.connected;

  /// Connect to the desktop via Wi-Fi UDP or Bluetooth
  Future<void> connect({
    required String host,
    required int port,
    required String pin,
    TransportType transport = TransportType.wifiUdp,
  }) async {
    serverAddress = host;
    serverPort = port;
    currentPin = pin;
    currentTransport = transport;

    status = ConnectionStatus.connecting;
    errorMessage = null;
    notifyListeners();

    try {
      if (transport == TransportType.wifiUdp) {
        await _connectUdp();
      } else {
        // Bluetooth RFCOMM connection placeholder
        await _connectBluetooth();
      }
    } catch (e) {
      status = ConnectionStatus.failed;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _connectUdp() async {
    _udpSocket?.close();
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udpSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram != null) {
          _handleIncomingPacket(datagram.data);
        }
      }
    });

    status = ConnectionStatus.authenticating;
    notifyListeners();

    // Send Auth Request packet
    _sendAuthRequest();

    // Start keepalive & ping loop
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (status == ConnectionStatus.connected) {
        _sendPing();
      } else if (status == ConnectionStatus.authenticating) {
        _sendAuthRequest(); // Retry auth
      }
    });
  }

  Future<void> _connectBluetooth() async {
    // Bluetooth connection routine
    status = ConnectionStatus.connecting;
    notifyListeners();
    // Connect to paired Bluetooth RFCOMM SPP socket
    await Future.delayed(const Duration(milliseconds: 500));
    _sendAuthRequest();
  }

  void _sendAuthRequest() {
    if (serverAddress == null || _udpSocket == null) return;
    try {
      final pinInt = int.tryParse(currentPin) ?? 0;
      final buffer = Uint8List(8);
      final view = ByteData.view(buffer.buffer);
      buffer[0] = 0x53; // 'S'
      buffer[1] = 0x57; // 'W'
      buffer[2] = PacketType.authRequest;
      buffer[3] = _sequence++ & 0xFF;
      view.setUint32(4, pinInt, Endian.little);

      final address = InternetAddress(serverAddress!);
      _udpSocket!.send(buffer, address, serverPort);
    } catch (e) {
      debugPrint("Error sending auth: $e");
    }
  }

  void _sendPing() {
    if (_udpSocket == null || serverAddress == null) return;
    _lastPingSent = DateTime.now();
    final buffer = Uint8List(4);
    buffer[0] = 0x53;
    buffer[1] = 0x57;
    buffer[2] = PacketType.ping;
    buffer[3] = _sequence++ & 0xFF;

    final address = InternetAddress(serverAddress!);
    _udpSocket!.send(buffer, address, serverPort);
  }

  void _handleIncomingPacket(Uint8List data) {
    if (data.length < 4) return;
    if (data[0] != 0x53 || data[1] != 0x57) return; // 'SW'

    final packetType = data[2];

    if (packetType == PacketType.authSuccess) {
      final view = ByteData.view(data.buffer);
      sessionToken = data.length >= 6 ? view.getUint16(4, Endian.little) : 0x77AA;
      status = ConnectionStatus.connected;
      errorMessage = null;
      notifyListeners();
    } else if (packetType == PacketType.authFailed) {
      status = ConnectionStatus.failed;
      errorMessage = "Invalid PIN code. Please check desktop code.";
      notifyListeners();
    } else if (packetType == PacketType.pong) {
      if (_lastPingSent != null) {
        currentLatencyMs = DateTime.now().difference(_lastPingSent!).inMilliseconds;
        notifyListeners();
      }
    }
  }

  /// Sends state packet with high power-efficiency (skips sending if no delta changes)
  void sendState(ControllerState state, {bool force = false}) {
    if (status != ConnectionStatus.connected || _udpSocket == null || serverAddress == null) {
      return;
    }

    // Delta compression: only transmit when input values change, saving phone battery & Wi-Fi airtime
    final hasDelta = force ||
        state.buttons != _lastSentButtons ||
        (state.leftStickX - _lastLStickX).abs() > 0.05 ||
        (state.leftStickY - _lastLStickY).abs() > 0.05 ||
        (state.rightStickX - _lastRStickX).abs() > 0.05 ||
        (state.rightStickY - _lastRStickY).abs() > 0.05;

    if (!hasDelta) return;

    _lastSentButtons = state.buttons;
    _lastLStickX = state.leftStickX;
    _lastLStickY = state.leftStickY;
    _lastRStickX = state.rightStickX;
    _lastRStickY = state.rightStickY;

    final packet = state.toBytes(_sequence++, sessionToken);
    final target = InternetAddress(serverAddress!);
    _udpSocket!.send(packet, target, serverPort);
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    status = ConnectionStatus.disconnected;
    sessionToken = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
