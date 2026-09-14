import 'package:flutter/material.dart';
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
    _pinController.text = conn.discoveredServer?.pin ?? conn.currentPin;
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
      _pinController.text = s.pin;
    }
    setState(() {});
  }

  void _saveAndConnect() {
    HapticService.instance.isEnabled = _vibrationEnabled;
    HapticService.instance.intensity = _intensity;

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
                    onSelected: (val) => setState(() => _transport = TransportType.bluetooth),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

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
            const SizedBox(height: 20),

            // Connect button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C3E3),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Connect to Desktop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                    '${server.ip}:${server.port} • PIN: ${server.pin} (Auto-Filled)',
                    style: const TextStyle(color: Color(0xFF00E676), fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _ipController.text = server.ip;
                _portController.text = server.port.toString();
                _pinController.text = server.pin;
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
}
