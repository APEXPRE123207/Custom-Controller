import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../../services/layout_service.dart';

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
  // Track press state by position (top/right/bottom/left), not label
  final Map<String, bool> _pressStates = {
    'top': false,
    'right': false,
    'bottom': false,
    'left': false,
  };

  void _handlePress(String position, int mask, bool pressed) {
    setState(() {
      _pressStates[position] = pressed;
    });
    widget.onButtonChange(mask, pressed);
    if (pressed) {
      HapticService.instance.triggerButton();
    }
  }

  Widget _buildButton({
    required String label,
    required String position,
    required int mask,
    required Color accentColor,
  }) {
    final isPressed = _pressStates[position] ?? false;

    return GestureDetector(
      onTapDown: (_) => _handlePress(position, mask, true),
      onTapUp: (_) => _handlePress(position, mask, false),
      onTapCancel: () => _handlePress(position, mask, false),
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
    final isXbox = LayoutService.instance.buttonLayoutMode == ButtonLayoutMode.xbox;

    // Nintendo: X(top), A(right), B(bottom), Y(left) — standard Switch Pro layout
    // Xbox:    Y(top), B(right), A(bottom), X(left) — standard Xbox 360 layout
    // The MASK stays the same per position; only the displayed LABEL swaps.
    final topLabel    = isXbox ? 'Y' : 'X';
    final rightLabel  = isXbox ? 'B' : 'A';
    final bottomLabel = isXbox ? 'A' : 'B';
    final leftLabel   = isXbox ? 'X' : 'Y';

    final accentColor = isXbox ? const Color(0xFF00C853) : const Color(0xFFFF4554);

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
          // Top button
          Positioned(
            top: 0,
            child: _buildButton(
              label: topLabel,
              position: 'top',
              mask: widget.xMask,  // Position "top" always sends X mask
              accentColor: accentColor,
            ),
          ),
          // Right button
          Positioned(
            right: 0,
            child: _buildButton(
              label: rightLabel,
              position: 'right',
              mask: widget.aMask,  // Position "right" always sends A mask
              accentColor: accentColor,
            ),
          ),
          // Bottom button
          Positioned(
            bottom: 0,
            child: _buildButton(
              label: bottomLabel,
              position: 'bottom',
              mask: widget.bMask,  // Position "bottom" always sends B mask
              accentColor: accentColor,
            ),
          ),
          // Left button
          Positioned(
            left: 0,
            child: _buildButton(
              label: leftLabel,
              position: 'left',
              mask: widget.yMask,  // Position "left" always sends Y mask
              accentColor: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
