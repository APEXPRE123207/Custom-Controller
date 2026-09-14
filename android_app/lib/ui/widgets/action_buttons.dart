import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class NintendoActionButtons extends StatefulWidget {
  final double size;
  final Function(int buttonMask, bool pressed) onButtonChange;
  final int aMask;
  final int bMask;
  final int xMask;
  final int yMask;

  const NintendoActionButtons({
    super.key,
    this.size = 145.0,
    required this.onButtonChange,
    required this.aMask,
    required this.bMask,
    required this.xMask,
    required this.yMask,
  });

  @override
  State<NintendoActionButtons> createState() => _NintendoActionButtonsState();
}

class _NintendoActionButtonsState extends State<NintendoActionButtons> {
  final Map<String, bool> _pressStates = {
    'A': false,
    'B': false,
    'X': false,
    'Y': false,
  };

  void _handlePress(String label, int mask, bool pressed) {
    setState(() {
      _pressStates[label] = pressed;
    });
    widget.onButtonChange(mask, pressed);
    if (pressed) {
      HapticService.instance.triggerButton();
    }
  }

  Widget _buildButton({
    required String label,
    required int mask,
    required Color accentColor,
  }) {
    final isPressed = _pressStates[label] ?? false;

    return GestureDetector(
      onTapDown: (_) => _handlePress(label, mask, true),
      onTapUp: (_) => _handlePress(label, mask, false),
      onTapCancel: () => _handlePress(label, mask, false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isPressed ? accentColor : const Color(0xFF262933),
          shape: BoxShape.circle,
          border: Border.all(
            color: isPressed ? Colors.white : const Color(0xFF3F4452),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (isPressed)
              BoxShadow(
                color: accentColor.withValues(alpha: 0.6),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isPressed ? Colors.white : const Color(0xFFE2E6EF),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Switch layout: X (top), A (right), B (bottom), Y (left)
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background disc
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFF191C24),
              shape: BoxShape.circle,
            ),
          ),
          // X (Top)
          Positioned(
            top: 0,
            child: _buildButton(
              label: 'X',
              mask: widget.xMask,
              accentColor: const Color(0xFFFF4554), // Joy-Con Neon Red
            ),
          ),
          // A (Right)
          Positioned(
            right: 0,
            child: _buildButton(
              label: 'A',
              mask: widget.aMask,
              accentColor: const Color(0xFFFF4554),
            ),
          ),
          // B (Bottom)
          Positioned(
            bottom: 0,
            child: _buildButton(
              label: 'B',
              mask: widget.bMask,
              accentColor: const Color(0xFFFF4554),
            ),
          ),
          // Y (Left)
          Positioned(
            left: 0,
            child: _buildButton(
              label: 'Y',
              mask: widget.yMask,
              accentColor: const Color(0xFFFF4554),
            ),
          ),
        ],
      ),
    );
  }
}
