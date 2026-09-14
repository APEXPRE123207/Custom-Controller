import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/controller_protocol.dart';
import '../services/connection_service.dart';
import '../services/layout_service.dart';
import 'settings_sheet.dart';
import 'widgets/action_buttons.dart';
import 'widgets/center_buttons.dart';
import 'widgets/customizable_control.dart';
import 'widgets/dpad.dart';
import 'widgets/joystick.dart';
import 'widgets/layout_edit_toolbar.dart';
import 'widgets/shoulder_buttons.dart';
import 'widgets/stick_click_button.dart';

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  final ControllerState _state = ControllerState();
  final ConnectionService _connection = ConnectionService.instance;
  final LayoutService _layout = LayoutService.instance;

  @override
  void initState() {
    super.initState();
    // Enforce landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _connection.addListener(_onUpdate);
    _layout.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _connection.removeListener(_onUpdate);
    _layout.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
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

  Widget _buildTopStatusBar() {
    final isConnected = _connection.isConnected;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Connection Pill
            GestureDetector(
              onTap: _openSettings,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFF132F24) : const Color(0xFF2A1C20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                          ? 'SwiCon Connected (${_connection.currentLatencyMs}ms)'
                          : 'SwiCon Disconnected - Tap to Connect',
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
            const SizedBox(width: 8),

            // Quick Edit Layout Button
            IconButton(
              tooltip: 'Customize Button Layout',
              icon: const Icon(Icons.tune_rounded, color: Color(0xFF00E676), size: 20),
              onPressed: () => _layout.toggleEditMode(true),
            ),

            // Settings Button
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = _layout.isEditMode;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Subtle background gaming grid in edit mode
              if (isEditMode)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF0F121C),
                    child: CustomPaint(
                      painter: _GridPainter(),
                    ),
                  ),
                ),

              // 1. LEFT STICK (Customizable)
              CustomizableControl(
                elementKey: 'leftStick',
                label: 'L-Stick / L3',
                screenConstraints: constraints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VirtualJoystick(
                      label: 'L',
                      size: 130,
                      accentColor: const Color(0xFF00C3E3),
                      onDirectionChanged: _updateLeftStick,
                      onStickClick: () {
                        _updateButton(ControllerButton.lStickBtn, true);
                        Future.delayed(const Duration(milliseconds: 150), () {
                          _updateButton(ControllerButton.lStickBtn, false);
                        });
                      },
                    ),
                    const SizedBox(height: 5),
                    NintendoStickClickButton(
                      label: 'L3 (F)',
                      buttonMask: ControllerButton.lStickBtn,
                      onButtonChange: _updateButton,
                      accentColor: const Color(0xFF00C3E3),
                    ),
                  ],
                ),
              ),

              // 2. D-PAD (Customizable)
              CustomizableControl(
                elementKey: 'dpad',
                label: 'D-Pad',
                screenConstraints: constraints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NintendoDpad(
                      size: 125,
                      dpadUpMask: ControllerButton.dpadUp,
                      dpadDownMask: ControllerButton.dpadDown,
                      dpadLeftMask: ControllerButton.dpadLeft,
                      dpadRightMask: ControllerButton.dpadRight,
                      onButtonChange: _updateButton,
                    ),
                    const SizedBox(height: 2),
                    const Text('D-PAD', style: TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ),

              // 3. RIGHT STICK (Customizable)
              CustomizableControl(
                elementKey: 'rightStick',
                label: 'R-Stick / R3',
                screenConstraints: constraints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VirtualJoystick(
                      label: 'R',
                      size: 130,
                      accentColor: const Color(0xFFFF4554),
                      onDirectionChanged: _updateRightStick,
                      onStickClick: () {
                        _updateButton(ControllerButton.rStickBtn, true);
                        Future.delayed(const Duration(milliseconds: 150), () {
                          _updateButton(ControllerButton.rStickBtn, false);
                        });
                      },
                    ),
                    const SizedBox(height: 5),
                    NintendoStickClickButton(
                      label: 'R3 (H)',
                      buttonMask: ControllerButton.rStickBtn,
                      onButtonChange: _updateButton,
                      accentColor: const Color(0xFFFF4554),
                    ),
                  ],
                ),
              ),

              // 4. ACTION BUTTONS A/B/X/Y (Customizable)
              CustomizableControl(
                elementKey: 'actionButtons',
                label: 'A/B/X/Y',
                screenConstraints: constraints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NintendoActionButtons(
                      size: 130,
                      aMask: ControllerButton.a,
                      bMask: ControllerButton.b,
                      xMask: ControllerButton.x,
                      yMask: ControllerButton.y,
                      onButtonChange: _updateButton,
                    ),
                    const SizedBox(height: 2),
                    const Text('A / B / X / Y', style: TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ),

              // 5. LEFT TRIGGERS ZL & L (Customizable)
              CustomizableControl(
                elementKey: 'leftTriggers',
                label: 'ZL / L',
                screenConstraints: constraints,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NintendoShoulderButton(
                      label: 'ZL',
                      buttonMask: ControllerButton.zl,
                      onButtonChange: _updateButton,
                      accentColor: const Color(0xFF00C3E3),
                      isTrigger: true,
                    ),
                    const SizedBox(width: 6),
                    NintendoShoulderButton(
                      label: 'L',
                      buttonMask: ControllerButton.l,
                      onButtonChange: _updateButton,
                      accentColor: const Color(0xFF00C3E3),
                    ),
                  ],
                ),
              ),

              // 6. RIGHT TRIGGERS ZR & R (Customizable)
              CustomizableControl(
                elementKey: 'rightTriggers',
                label: 'ZR / R',
                screenConstraints: constraints,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NintendoShoulderButton(
                      label: 'R',
                      buttonMask: ControllerButton.r,
                      onButtonChange: _updateButton,
                      accentColor: const Color(0xFFFF4554),
                    ),
                    const SizedBox(width: 6),
                    NintendoShoulderButton(
                      label: 'ZR',
                      buttonMask: ControllerButton.zr,
                      onButtonChange: _updateButton,
                      accentColor: const Color(0xFFFF4554),
                      isTrigger: true,
                    ),
                  ],
                ),
              ),

              // 7. CENTER CONSOLE BUTTONS (Customizable)
              CustomizableControl(
                elementKey: 'centerButtons',
                label: 'Center Console',
                screenConstraints: constraints,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Minus (-) & Plus (+)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NintendoCenterButton(
                          text: '−',
                          buttonMask: ControllerButton.minus,
                          onButtonChange: _updateButton,
                        ),
                        const SizedBox(width: 14),
                        NintendoCenterButton(
                          text: '+',
                          buttonMask: ControllerButton.plus,
                          onButtonChange: _updateButton,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // SwiCon circular logo emblem
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00C3E3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon/app_logo_circle.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.sports_esports_rounded, color: Colors.white70, size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text('SwiCon', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Capture & Home
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NintendoCenterButton(
                          icon: Icons.crop_square_rounded,
                          isSquare: true,
                          buttonMask: ControllerButton.capture,
                          onButtonChange: _updateButton,
                        ),
                        const SizedBox(width: 14),
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

              // Header Bar: Either Edit Toolbar OR Regular Status Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: isEditMode ? const LayoutEditToolbar() : _buildTopStatusBar(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Custom painter to render an edit grid overlay
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E2433).withValues(alpha: 0.4)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
