import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import '../services/haptic_service.dart';
import '../services/connection_service.dart';
import '../services/layout_service.dart';

class ControllerSettingsSheet extends StatefulWidget {
  const ControllerSettingsSheet({super.key});

  @override
  State<ControllerSettingsSheet> createState() => _ControllerSettingsSheetState();
}

class _ControllerSettingsSheetState extends State<ControllerSettingsSheet> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  final _pinController = TextEditingController();

  TransportType _transport = TransportType.wifiUdp;
  bool _vibrationEnabled = true;
  HapticIntensity _intensity = HapticIntensity.light;

  @override
  void initState() {
    super.initState();
    final conn = ConnectionService.instance;
    conn.addListener(_onConnectionServiceUpdate);
    _ipController.text = conn.discoveredServer?.ip ?? conn.serverAddress ?? '';
    _portController.text = (conn.discoveredServer?.port ?? conn.serverPort).toString();
    _pinController.text = '';  // PIN must always be entered manually for security
    _transport = conn.currentTransport;

    final haptic = HapticService.instance;
    _vibrationEnabled = haptic.isEnabled;
    _intensity = haptic.intensity;

    if (!conn.isConnected) {
      conn.startDiscovery();
    }
  }

  @override
  void dispose() {
    ConnectionService.instance.removeListener(_onConnectionServiceUpdate);
    _ipController.dispose();
    _portController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onConnectionServiceUpdate() {
    if (!mounted) return;
    final conn = ConnectionService.instance;
    if (conn.discoveredServer != null) {
      final s = conn.discoveredServer!;
      if (_ipController.text.isEmpty || _ipController.text.endsWith('.')) {
        _ipController.text = s.ip;
      }
      _portController.text = s.port.toString();
      // PIN is intentionally NOT auto-filled for security
    }
    setState(() {});
  }

  void _saveAndConnect() {
    HapticService.instance.isEnabled = _vibrationEnabled;
    HapticService.instance.intensity = _intensity;

    if (_transport == TransportType.bluetooth) {
      // Bluetooth connect
      final conn = ConnectionService.instance;
      if (conn.selectedBluetoothDevice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a paired Bluetooth device first'),
            backgroundColor: Color(0xFFFF4554),
          ),
        );
        return;
      }
      final pin = _pinController.text.trim();
      if (pin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter the Security PIN shown on your PC'),
            backgroundColor: Color(0xFFFF4554),
          ),
        );
        return;
      }
      conn.connectBluetooth(
        device: conn.selectedBluetoothDevice!,
        pin: pin,
      );
      Navigator.of(context).pop();
    } else {
      // Wi-Fi connect
      final ip = _ipController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 8899;
      final pin = _pinController.text.trim();

      ConnectionService.instance.connect(
        host: ip,
        port: port,
        pin: pin,
        transport: _transport,
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF191C24),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: Color(0xFF00C3E3)),
                    SizedBox(width: 8),
                    Text(
                      'Controller Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF2C303B), height: 24),

            // Vibration & Haptics Section
            const Text(
              'Haptic & Vibration Feedback',
              style: TextStyle(color: Color(0xFF00C3E3), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable Controller Vibrations', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('Tactile response on button taps and triggers', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _vibrationEnabled,
              activeThumbColor: const Color(0xFF00C3E3),
              onChanged: (val) {
                setState(() => _vibrationEnabled = val);
                if (val) HapticService.instance.triggerButton();
              },
            ),

            if (_vibrationEnabled) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Vibration Intensity', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  SegmentedButton<HapticIntensity>(
                    segments: const [
                      ButtonSegment(value: HapticIntensity.light, label: Text('Light', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: HapticIntensity.medium, label: Text('Med', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: HapticIntensity.heavy, label: Text('Heavy', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {_intensity},
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF00C3E3).withValues(alpha: 0.3);
                        }
                        return const Color(0xFF242833);
                      }),
                    ),
                    onSelectionChanged: (set) {
                      setState(() => _intensity = set.first);
                      HapticService.instance.intensity = set.first;
                      HapticService.instance.triggerButton();
                    },
                  ),
                ],
              ),
            ],

            const Divider(color: Color(0xFF2C303B), height: 28),

            // Button Layout & Sizing Section
            const Text(
              'Button Layout & Size Customization',
              style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF202430),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Button Face Label Layout',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Switch between Nintendo and Xbox button label positions.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<ButtonLayoutMode>(
                          segments: const [
                            ButtonSegment(
                              value: ButtonLayoutMode.nintendo,
                              label: Text('🎮 Nintendo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            ButtonSegment(
                              value: ButtonLayoutMode.xbox,
                              label: Text('🟢 Xbox', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                          selected: {LayoutService.instance.buttonLayoutMode},
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFF00E676).withValues(alpha: 0.25);
                              }
                              return const Color(0xFF242833);
                            }),
                          ),
                          onSelectionChanged: (set) {
                            setState(() {
                              LayoutService.instance.setButtonLayoutMode(set.first);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181C26),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF262C3A)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLayoutDiamondPreview(LayoutService.instance.buttonLayoutMode),
                        const SizedBox(width: 14),
                        Text(
                          LayoutService.instance.buttonLayoutMode == ButtonLayoutMode.nintendo
                              ? 'Nintendo Switch Layout'
                              : 'Xbox 360 / One Layout',
                          style: TextStyle(
                            color: LayoutService.instance.buttonLayoutMode == ButtonLayoutMode.nintendo
                                ? const Color(0xFFFF4554)
                                : const Color(0xFF00E676),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Customize Button Positions & Sizes',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Drag buttons anywhere on your screen and adjust their sizes to match your hand ergonomics.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.touch_app_rounded, size: 18),
                      label: const Text('Enter Layout Edit Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        Navigator.of(context).pop();
                        LayoutService.instance.toggleEditMode(true);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF2C303B), height: 28),

            // Connection Mode
            const Text(
              'Connection & Security',
              style: TextStyle(color: Color(0xFFFF4554), fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Wi-Fi / Hotspot (Low Latency)')),
                    selected: _transport == TransportType.wifiUdp,
                    selectedColor: const Color(0xFF00C3E3).withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: _transport == TransportType.wifiUdp ? const Color(0xFF00C3E3) : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) => setState(() => _transport = TransportType.wifiUdp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Bluetooth')),
                    selected: _transport == TransportType.bluetooth,
                    selectedColor: const Color(0xFFFF4554).withValues(alpha: 0.25),
                    labelStyle: TextStyle(
                      color: _transport == TransportType.bluetooth ? const Color(0xFFFF4554) : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      setState(() => _transport = TransportType.bluetooth);
                      // Load paired Bluetooth devices when BT is selected
                      ConnectionService.instance.loadBluetoothDevices();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- Transport-specific UI ---
            if (_transport == TransportType.wifiUdp) ...[
              // Auto-Discovery Card
              _buildAutoDiscoveryBanner(ConnectionService.instance),
              const SizedBox(height: 14),

              // Desktop IP Address
              TextField(
                controller: _ipController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Desktop Receiver IP Address',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  hintText: 'e.g. 192.168.1.50',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF222631),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.computer_rounded, color: Colors.white54, size: 20),
                ),
              ),
              const SizedBox(height: 10),

              // Port & PIN
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Port',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF222631),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
                      decoration: InputDecoration(
                        labelText: 'Security PIN',
                        labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                        hintText: '1234',
                        filled: true,
                        fillColor: const Color(0xFF222631),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Bluetooth device picker
              _buildBluetoothDevicePicker(),
              const SizedBox(height: 10),
              // PIN field for Bluetooth too
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 2),
                decoration: InputDecoration(
                  labelText: 'Security PIN',
                  labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                  hintText: 'Enter PIN shown on desktop',
                  filled: true,
                  fillColor: const Color(0xFF222631),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Connect button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _transport == TransportType.bluetooth
                      ? const Color(0xFF2196F3)
                      : const Color(0xFF00C3E3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(_transport == TransportType.bluetooth
                    ? Icons.bluetooth_connected_rounded
                    : Icons.link_rounded),
                label: Text(
                  _transport == TransportType.bluetooth
                      ? 'Connect via Bluetooth'
                      : 'Connect to Desktop',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _saveAndConnect,
              ),
            ),
            const SizedBox(height: 10),

            if (ConnectionService.instance.isConnected)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Disconnect'),
                  onPressed: () {
                    ConnectionService.instance.disconnect();
                    Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildAutoDiscoveryBanner(ConnectionService conn) {
    final server = conn.discoveredServer;

    if (server != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF132F24),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00E676), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E676).withValues(alpha: 0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PC Auto-Detected: ${server.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${server.ip}:${server.port} • PIN: Enter Manually 🔒',
                    style: const TextStyle(color: Color(0xFF00E676), fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _ipController.text = server.ip;
                _portController.text = server.port.toString();
                // PIN is NOT auto-filled — user must type it manually
                if (_pinController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter the Security PIN shown on your PC to connect'),
                      backgroundColor: Color(0xFFFF4554),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  return;
                }
                _saveAndConnect();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('1-Tap Connect', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      );
    }

    if (conn.isSearching) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF142434),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00C3E3).withValues(alpha: 0.6), width: 1.2),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00C3E3)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Auto-detecting SwiCon PC Receiver on Wi-Fi...',
                style: TextStyle(color: Color(0xFF00C3E3), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF202430),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333A4C)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.wifi_find_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text('Wi-Fi Auto-Discovery', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          TextButton.icon(
            onPressed: () => conn.startDiscovery(),
            icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF00C3E3)),
            label: const Text('Scan Local Network', style: TextStyle(color: Color(0xFF00C3E3), fontSize: 11, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothDevicePicker() {
    final conn = ConnectionService.instance;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2196F3).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth_rounded, color: Color(0xFF2196F3), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Select Paired Device',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  conn.loadBluetoothDevices();
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF2196F3)),
                label: const Text('Refresh', style: TextStyle(color: Color(0xFF2196F3), fontSize: 11, fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!conn.isBluetoothAvailable) ...[
            _buildBtStatusCard(
              icon: Icons.bluetooth_disabled_rounded,
              text: 'Bluetooth is not available on this device.',
              color: const Color(0xFFFF6B6B),
            ),
          ] else if (!conn.isBluetoothEnabled) ...[
            _buildBtStatusCard(
              icon: Icons.bluetooth_disabled_rounded,
              text: 'Bluetooth is turned off.',
              color: const Color(0xFFFFA000),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.bluetooth_rounded, size: 16),
                label: const Text('Enable Bluetooth', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await conn.requestEnableBluetooth();
                  setState(() {});
                },
              ),
            ),
          ] else if (conn.isLoadingDevices) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2196F3)),
              ),
            ),
          ] else if (conn.pairedDevices.isEmpty) ...[
            _buildBtStatusCard(
              icon: Icons.device_unknown_rounded,
              text: 'No paired devices found.\nPair your PC in Android Bluetooth settings first.',
              color: const Color(0xFFFFA000),
            ),
          ] else ...[
            const Text(
              'Tap your PC from the list below:',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 6),
            ...conn.pairedDevices.map((device) {
              final isSelected = conn.selectedBluetoothDevice?.address == device.address;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    conn.selectBluetoothDevice(device);
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2196F3).withValues(alpha: 0.2) : const Color(0xFF202430),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF333A4C),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getBtDeviceIcon(device),
                        color: isSelected ? const Color(0xFF2196F3) : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name ?? 'Unknown Device',
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              device.address,
                              style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF2196F3), size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBtStatusCard({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBtDeviceIcon(BtcDevice device) {
    final name = (device.name ?? '').toLowerCase();
    if (name.contains('laptop') || name.contains('notebook')) {
      return Icons.laptop_rounded;
    } else if (name.contains('desktop') || name.contains('pc') || name.contains('swicon')) {
      return Icons.computer_rounded;
    } else if (name.contains('phone') || name.contains('pixel') || name.contains('samsung')) {
      return Icons.phone_android_rounded;
    }
    return Icons.devices_rounded;
  }

  Widget _buildLayoutDiamondPreview(ButtonLayoutMode mode) {
    final bool isNintendo = mode == ButtonLayoutMode.nintendo;
    final topLabel = isNintendo ? 'X' : 'Y';
    final rightLabel = isNintendo ? 'A' : 'B';
    final bottomLabel = isNintendo ? 'B' : 'A';
    final leftLabel = isNintendo ? 'Y' : 'X';

    final topColor = isNintendo ? const Color(0xFF40C4FF) : const Color(0xFFFFD54F);
    final rightColor = isNintendo ? const Color(0xFFFF5252) : const Color(0xFFFF5252);
    final bottomColor = isNintendo ? const Color(0xFFFFD54F) : const Color(0xFF69F0AE);
    final leftColor = isNintendo ? const Color(0xFF69F0AE) : const Color(0xFF40C4FF);

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle diamond border background
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF13161F),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          // Top button
          Positioned(
            top: 0,
            child: _buildMiniDiamondBtn(topLabel, topColor),
          ),
          // Right button
          Positioned(
            right: 0,
            child: _buildMiniDiamondBtn(rightLabel, rightColor),
          ),
          // Bottom button
          Positioned(
            bottom: 0,
            child: _buildMiniDiamondBtn(bottomLabel, bottomColor),
          ),
          // Left button
          Positioned(
            left: 0,
            child: _buildMiniDiamondBtn(leftLabel, leftColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDiamondBtn(String label, Color color) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: const Color(0xFF222836),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          height: 1.0,
        ),
      ),
    );
  }
}
