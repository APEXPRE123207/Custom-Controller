import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/controller_protocol.dart';
import '../services/connection_service.dart';
import 'settings_sheet.dart';
import 'widgets/action_buttons.dart';
import 'widgets/center_buttons.dart';
import 'widgets/dpad.dart';
import 'widgets/joystick.dart';
import 'widgets/shoulder_buttons.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  final ControllerState _state = ControllerState();
  final ConnectionService _connection = ConnectionService.instance;

  @override
  void initState() {
    super.initState();
    // Enforce landscape orientation for ergonomic console experience
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Fullscreen immersion
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _connection.addListener(_onConnectionUpdate);
  }

  @override
  void dispose() {
    _connection.removeListener(_onConnectionUpdate);
    super.dispose();
  }

  void _onConnectionUpdate() {
    if (mounted) setState(() {});
  }

  void _updateButton(int mask, bool pressed) {
    _state.setButton(mask, pressed);
    _connection.sendState(_state);
  }

  void _updateLeftStick(Offset delta) {
    _state.leftStickX = delta.dx;
    _state.leftStickY = delta.dy;
    _connection.sendState(_state);
  }

  void _updateRightStick(Offset delta) {
    _state.rightStickX = delta.dx;
    _state.rightStickY = delta.dy;
    _connection.sendState(_state);
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ControllerSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connection.isConnected;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      body: SafeArea(
        child: Column(
          children: [
            // Top Shoulder Buttons & Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF161820),
                border: Border(bottom: BorderSide(color: Color(0xFF222631), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Triggers (ZL, L)
                  Row(
                    children: [
                      NintendoShoulderButton(
                        label: 'ZL',
                        buttonMask: ControllerButton.zl,
                        onButtonChange: _updateButton,
                        accentColor: const Color(0xFF00C3E3),
                        isTrigger: true,
                      ),
                      const SizedBox(width: 8),
                      NintendoShoulderButton(
                        label: 'L',
                        buttonMask: ControllerButton.l,
                        onButtonChange: _updateButton,
                        accentColor: const Color(0xFF00C3E3),
                      ),
                    ],
                  ),

                  // Center Status Bar
                  Row(
                    children: [
                      // Connection Status Pill
                      GestureDetector(
                        onTap: _openSettings,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF132F24)
                                : const Color(0xFF2A1C20),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isConnected
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF5252),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isConnected ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isConnected
                                    ? 'Connected (${_connection.currentLatencyMs}ms)'
                                    : 'Disconnected - Tap to Setup',
                                style: TextStyle(
                                  color: isConnected ? const Color(0xFF00E676) : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                        onPressed: _openSettings,
                      ),
                    ],
                  ),

                  // Right Triggers (R, ZR)
                  Row(
                    children: [
                      NintendoShoulderButton(
                        label: 'R',
                        buttonMask: ControllerButton.r,
                        onButtonChange: _updateButton,
                        accentColor: const Color(0xFFFF4554),
                      ),
                      const SizedBox(width: 8),
                      NintendoShoulderButton(
                        label: 'ZR',
                        buttonMask: ControllerButton.zr,
                        onButtonChange: _updateButton,
                        accentColor: const Color(0xFFFF4554),
                        isTrigger: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Main Controller Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    // LEFT JOY-CON / PRO SECTION (Neon Cyan Theme)
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14171F),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF00C3E3).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Left Analog Stick (L-Stick)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                VirtualJoystick(
                                  label: 'L',
                                  size: 132,
                                  accentColor: const Color(0xFF00C3E3),
                                  onDirectionChanged: _updateLeftStick,
                                  onStickClick: () {
                                    _updateButton(ControllerButton.lStickBtn, true);
                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      _updateButton(ControllerButton.lStickBtn, false);
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                const Text('L-Stick (F)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),

                            // D-Pad (Up, Down, Left, Right)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                NintendoDpad(
                                  size: 130,
                                  dpadUpMask: ControllerButton.dpadUp,
                                  dpadDownMask: ControllerButton.dpadDown,
                                  dpadLeftMask: ControllerButton.dpadLeft,
                                  dpadRightMask: ControllerButton.dpadRight,
                                  onButtonChange: _updateButton,
                                ),
                                const SizedBox(height: 4),
                                const Text('D-PAD', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // CENTER SWITCH BAR (- / + / Capture / Home)
                    Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Minus (-) & Plus (+) buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              NintendoCenterButton(
                                text: '−',
                                buttonMask: ControllerButton.minus,
                                onButtonChange: _updateButton,
                              ),
                              NintendoCenterButton(
                                text: '+',
                                buttonMask: ControllerButton.plus,
                                onButtonChange: _updateButton,
                              ),
                            ],
                          ),

                          // Brand / Console emblem
                          Column(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24, width: 2),
                                ),
                                child: const Icon(Icons.sports_esports_rounded, color: Colors.white38, size: 16),
                              ),
                              const SizedBox(height: 4),
                              const Text('SWITCH', style: TextStyle(color: Colors.white24, fontSize: 8, letterSpacing: 1.5)),
                            ],
                          ),

                          // Capture & Home buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              NintendoCenterButton(
                                icon: Icons.crop_square_rounded,
                                isSquare: true,
                                buttonMask: ControllerButton.capture,
                                onButtonChange: _updateButton,
                              ),
                              NintendoCenterButton(
                                icon: Icons.home_rounded,
                                buttonMask: ControllerButton.home,
                                onButtonChange: _updateButton,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // RIGHT JOY-CON / PRO SECTION (Neon Red Theme)
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14171F),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFFFF4554).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // Right Stick (R-Stick)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                VirtualJoystick(
                                  label: 'R',
                                  size: 132,
                                  accentColor: const Color(0xFFFF4554),
                                  onDirectionChanged: _updateRightStick,
                                  onStickClick: () {
                                    _updateButton(ControllerButton.rStickBtn, true);
                                    Future.delayed(const Duration(milliseconds: 150), () {
                                      _updateButton(ControllerButton.rStickBtn, false);
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                const Text('R-Stick (H)', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),

                            // Action Buttons (A, B, X, Y diamond)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                NintendoActionButtons(
                                  size: 132,
                                  aMask: ControllerButton.a,
                                  bMask: ControllerButton.b,
                                  xMask: ControllerButton.x,
                                  yMask: ControllerButton.y,
                                  onButtonChange: _updateButton,
                                ),
                                const SizedBox(height: 4),
                                const Text('A / B / X / Y', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
