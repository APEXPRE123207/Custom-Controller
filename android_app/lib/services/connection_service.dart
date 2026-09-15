import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
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

class DiscoveredServer {
  final String ip;
  final int port;
  final String pin;
  final String name;

  const DiscoveredServer({
    required this.ip,
    required this.port,
    required this.pin,
    required this.name,
  });
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

  // Auto-Discovery State
  DiscoveredServer? discoveredServer;
  bool isSearching = false;
  RawDatagramSocket? _discoverySocket;
  Timer? _discoveryTimer;

  int sessionToken = 0;
  int _sequence = 0;
  int currentLatencyMs = 0;
  String? errorMessage;

  // --- Wi-Fi UDP State ---
  RawDatagramSocket? _udpSocket;
  Timer? _heartbeatTimer;
  DateTime? _lastPingSent;
  int _lastSentButtons = 0;
  double _lastLStickX = 0;
  double _lastLStickY = 0;
  double _lastRStickX = 0;
  double _lastRStickY = 0;

  // --- Bluetooth State ---
  final FlutterClassicBluetooth _bluetooth = FlutterClassicBluetooth();
  BtcConnection? _btConnection;
  BtcDevice? selectedBluetoothDevice;
  List<BtcDevice> pairedDevices = [];
  bool isBluetoothAvailable = false;
  bool isBluetoothEnabled = false;
  bool isLoadingDevices = false;
  List<int> _btReceiveBuffer = [];

  bool get isConnected => status == ConnectionStatus.connected;

  // ========================================================================
  // Bluetooth Device Management
  // ========================================================================

  /// Check Bluetooth state and load paired devices
  Future<void> loadBluetoothDevices() async {
    isLoadingDevices = true;
    notifyListeners();

    try {
      isBluetoothAvailable = await _bluetooth.isSupported();
      isBluetoothEnabled = await _bluetooth.isEnabled();

      if (isBluetoothEnabled) {
        pairedDevices = await _bluetooth.getPairedDevices();
      } else {
        pairedDevices = [];
      }
    } catch (e) {
      debugPrint("Error loading BT devices: $e");
      isBluetoothAvailable = false;
      isBluetoothEnabled = false;
      pairedDevices = [];
    }

    isLoadingDevices = false;
    notifyListeners();
  }

  /// Request the user to enable Bluetooth
  Future<bool> requestEnableBluetooth() async {
    try {
      final caps = await _bluetooth.getPlatformCapabilities();
      if (caps.canEnableBluetooth) {
        await _bluetooth.enableBluetooth();
        // Wait a moment for the adapter to come up
        await Future.delayed(const Duration(milliseconds: 500));
        isBluetoothEnabled = await _bluetooth.isEnabled();
        if (isBluetoothEnabled) {
          await loadBluetoothDevices();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error enabling BT: $e");
    }
    return false;
  }

  void selectBluetoothDevice(BtcDevice device) {
    selectedBluetoothDevice = device;
    notifyListeners();
  }

  // ========================================================================
  // Connection
  // ========================================================================

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
        await _connectBluetooth();
      }
    } catch (e) {
      status = ConnectionStatus.failed;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Connect to the desktop using Bluetooth with the selected device
  Future<void> connectBluetooth({
    required BtcDevice device,
    required String pin,
  }) async {
    selectedBluetoothDevice = device;
    currentPin = pin;
    currentTransport = TransportType.bluetooth;

    status = ConnectionStatus.connecting;
    errorMessage = null;
    notifyListeners();

    try {
      await _connectBluetooth();
    } catch (e) {
      status = ConnectionStatus.failed;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ========================================================================
  // Wi-Fi UDP Transport
  // ========================================================================

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

  void _sendAuthRequest() {
    final pinInt = int.tryParse(currentPin) ?? 0;
    final buffer = Uint8List(8);
    final view = ByteData.view(buffer.buffer);
    buffer[0] = 0x53; // 'S'
    buffer[1] = 0x57; // 'W'
    buffer[2] = PacketType.authRequest;
    buffer[3] = _sequence++ & 0xFF;
    view.setUint32(4, pinInt, Endian.little);

    _sendPacket(buffer);
  }

  void _sendPing() {
    _lastPingSent = DateTime.now();
    final buffer = Uint8List(4);
    buffer[0] = 0x53;
    buffer[1] = 0x57;
    buffer[2] = PacketType.ping;
    buffer[3] = _sequence++ & 0xFF;

    _sendPacket(buffer);
  }

  /// Unified packet sender — routes to UDP or Bluetooth based on active transport
  void _sendPacket(Uint8List data) {
    try {
      if (currentTransport == TransportType.wifiUdp) {
        if (_udpSocket != null && serverAddress != null) {
          final address = InternetAddress(serverAddress!);
          _udpSocket!.send(data, address, serverPort);
        }
      } else {
        // Bluetooth: send over RFCOMM stream
        if (_btConnection != null && _btConnection!.isConnected) {
          _btConnection!.output.add(data);
        }
      }
    } catch (e) {
      debugPrint("Error sending packet: $e");
    }
  }

  // ========================================================================
  // Bluetooth RFCOMM Transport
  // ========================================================================

  Future<void> _connectBluetooth() async {
    if (selectedBluetoothDevice == null) {
      throw Exception("No Bluetooth device selected. Please select your PC from the paired devices list.");
    }

    final address = selectedBluetoothDevice!.address;
    debugPrint("[BT] Connecting to ${selectedBluetoothDevice!.displayName} ($address)...");

    // Close any existing Bluetooth connection
    try {
      await _btConnection?.close();
    } catch (_) {}

    // Request permissions first (both connect and scan are required by Android when connecting)
    try {
      final permStatus = await _bluetooth.checkPermissions(
        permissions: {BtcPermission.connect, BtcPermission.scan},
      );
      if (permStatus == BtcPermissionStatus.denied) {
        await _bluetooth.requestPermissions(
          permissions: {BtcPermission.connect, BtcPermission.scan},
        );
      }
    } catch (e) {
      debugPrint("[BT] Permission check: $e");
    }

    // Connect via RFCOMM SPP (try secure first, fallback to insecure)
    try {
      _btConnection = await _bluetooth.connect(
        address: address,
        secure: true,
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      debugPrint("[BT] Secure RFCOMM connect failed: $e, trying insecure...");
      try {
        _btConnection = await _bluetooth.connect(
          address: address,
          secure: false,
          timeout: const Duration(seconds: 8),
        );
      } catch (e2) {
        throw Exception("Bluetooth connection failed: $e2\n\nMake sure:\n1. Your PC is paired with this phone\n2. SwiCon Desktop is running with Bluetooth enabled\n3. Bluetooth is on for both devices");
      }
    }

    if (_btConnection == null || !_btConnection!.isConnected) {
      throw Exception("Bluetooth connection could not be established.");
    }

    debugPrint("[BT] RFCOMM connected! Starting auth...");

    // Listen for incoming data on the Bluetooth stream
    _btReceiveBuffer = [];
    _btConnection!.input.listen(
      (Uint8List data) {
        _btReceiveBuffer.addAll(data);
        _processBtBuffer();
      },
      onDone: () {
        debugPrint("[BT] Stream closed by remote");
        if (status == ConnectionStatus.connected) {
          status = ConnectionStatus.disconnected;
          errorMessage = "Bluetooth connection lost.";
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("[BT] Stream error: $error");
        if (status == ConnectionStatus.connected) {
          status = ConnectionStatus.failed;
          errorMessage = "Bluetooth error: $error";
          notifyListeners();
        }
      },
      cancelOnError: false,
    );

    // Authenticate
    status = ConnectionStatus.authenticating;
    notifyListeners();

    _sendAuthRequest();

    // Start heartbeat (same as UDP)
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (status == ConnectionStatus.connected) {
        _sendPing();
      } else if (status == ConnectionStatus.authenticating) {
        _sendAuthRequest(); // Retry auth
      }
    });
  }

  /// Process buffered Bluetooth bytes — frame packets using 'SW' magic header
  void _processBtBuffer() {
    while (_btReceiveBuffer.length >= 4) {
      // Find magic header 'SW'
      if (_btReceiveBuffer[0] != 0x53 || _btReceiveBuffer[1] != 0x57) {
        _btReceiveBuffer.removeAt(0); // Skip invalid byte
        continue;
      }

      final packetType = _btReceiveBuffer[2];
      int packetLen;

      // Determine expected packet length based on type
      switch (packetType) {
        case PacketType.authSuccess:
          packetLen = 6; // SW + type + seq + 2-byte token
          break;
        case PacketType.authFailed:
        case PacketType.pong:
          packetLen = 4; // SW + type + seq
          break;
        default:
          // Unknown type, skip this byte
          _btReceiveBuffer.removeAt(0);
          continue;
      }

      if (_btReceiveBuffer.length < packetLen) {
        break; // Wait for more data
      }

      // Extract and process the packet
      final packet = Uint8List.fromList(_btReceiveBuffer.sublist(0, packetLen));
      _btReceiveBuffer.removeRange(0, packetLen);
      _handleIncomingPacket(packet);
    }
  }

  // ========================================================================
  // Incoming Packet Handler (shared by UDP and Bluetooth)
  // ========================================================================

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

  // ========================================================================
  // Send Controller State (shared by UDP and Bluetooth)
  // ========================================================================

  /// Sends state packet with high power-efficiency (skips sending if no delta changes)
  void sendState(ControllerState state, {bool force = false}) {
    if (status != ConnectionStatus.connected) return;

    // Check transport-specific connectivity
    if (currentTransport == TransportType.wifiUdp) {
      if (_udpSocket == null || serverAddress == null) return;
    } else {
      if (_btConnection == null || !_btConnection!.isConnected) return;
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
    _sendPacket(packet);
  }

  // ========================================================================
  // Wi-Fi Auto-Discovery
  // ========================================================================

  /// Starts scanning the local network for SwiCon desktop receivers
  Future<void> startDiscovery() async {
    if (isSearching || isConnected) return;
    isSearching = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      _discoverySocket?.close();
      _discoverySocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _discoverySocket!.broadcastEnabled = true;
      _discoverySocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _discoverySocket?.receive();
          if (dg != null) {
            _handleDiscoveryResponse(dg);
          }
        }
      });

      // Send initial discovery probe
      _sendDiscoveryProbes();

      // Probe periodically every 900ms for up to 6 cycles
      int attempts = 0;
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) {
        attempts++;
        if (attempts >= 6 || isConnected || discoveredServer != null) {
          timer.cancel();
          isSearching = false;
          notifyListeners();
        } else {
          _sendDiscoveryProbes();
        }
      });
    } catch (_) {
      isSearching = false;
      notifyListeners();
    }
  }

  void stopDiscovery({bool notify = true}) {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    if (isSearching) {
      isSearching = false;
      if (notify) notifyListeners();
    }
  }

  void _sendDiscoveryProbes() {
    if (_discoverySocket == null) return;
    // Magic: 'S', 'W', Type: 7 (discover), Seq: 0
    final probe = Uint8List.fromList([0x53, 0x57, PacketType.discover, 0x00]);

    // 1. Send broadcast to global 255.255.255.255:8899
    try {
      _discoverySocket!.send(probe, InternetAddress('255.255.255.255'), 8899);
    } catch (_) {}

    // 2. Send broadcast to all local network subnet broadcast addresses (X.X.X.255:8899)
    NetworkInterface.list(type: InternetAddressType.IPv4).then((interfaces) {
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final subnetBcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              try {
                _discoverySocket?.send(probe, InternetAddress(subnetBcast), 8899);
              } catch (_) {}
            }
          }
        }
      }
    }).catchError((_) {});
  }

  void _handleDiscoveryResponse(Datagram dg) {
    final data = dg.data;
    if (data.length < 10) return;
    if (data[0] != 0x53 || data[1] != 0x57) return; // 'SW'
    if (data[2] != PacketType.discoverReply) return; // Type 8

    final view = ByteData.view(data.buffer, data.offsetInBytes);
    final port = view.getUint16(4, Endian.little);
    final pinVal = view.getUint32(6, Endian.little);

    String serverName = "SwiCon Desktop";
    if (data.length >= 11) {
      final nameLen = data[10];
      if (data.length >= 11 + nameLen) {
        serverName = String.fromCharCodes(data.sublist(11, 11 + nameLen));
      }
    }

    discoveredServer = DiscoveredServer(
      ip: dg.address.address,
      port: port > 0 ? port : 8899,
      pin: pinVal.toString(),
      name: serverName,
    );

    // Auto-fill only IP and Port — PIN requires manual entry for security
    serverAddress = dg.address.address;
    serverPort = port > 0 ? port : 8899;
    // NOTE: We intentionally do NOT auto-fill currentPin from discovery.
    // The PIN must be entered manually by the user.

    isSearching = false;
    _discoveryTimer?.cancel();
    notifyListeners();
  }

  // ========================================================================
  // Disconnect & Cleanup
  // ========================================================================

  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    // Clean up UDP
    _udpSocket?.close();
    _udpSocket = null;

    // Clean up Bluetooth
    try {
      _btConnection?.close();
    } catch (_) {}
    _btConnection = null;
    _btReceiveBuffer = [];

    // Reset delta tracking
    _lastSentButtons = 0;
    _lastLStickX = 0;
    _lastLStickY = 0;
    _lastRStickX = 0;
    _lastRStickY = 0;

    status = ConnectionStatus.disconnected;
    sessionToken = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stopDiscovery();
    disconnect();
    super.dispose();
  }
}
