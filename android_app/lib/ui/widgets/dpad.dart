import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class NintendoDpad extends StatefulWidget {
  final double size;
  final Function(int buttonMask, bool pressed) onButtonChange;
  final int dpadUpMask;
  final int dpadDownMask;
  final int dpadLeftMask;
  final int dpadRightMask;

  const NintendoDpad({
    super.key,
    this.size = 135.0,
    required this.onButtonChange,
    required this.dpadUpMask,
    required this.dpadDownMask,
    required this.dpadLeftMask,
    required this.dpadRightMask,
  });

  @override
  State<NintendoDpad> createState() => _NintendoDpadState();
}

class _NintendoDpadState extends State<NintendoDpad> {
  bool _upPressed = false;
  bool _downPressed = false;
  bool _leftPressed = false;
  bool _rightPressed = false;

  void _handlePress(String direction, bool pressed) {
    setState(() {
      if (direction == 'up') {
        _upPressed = pressed;
        widget.onButtonChange(widget.dpadUpMask, pressed);
      } else if (direction == 'down') {
        _downPressed = pressed;
        widget.onButtonChange(widget.dpadDownMask, pressed);
      } else if (direction == 'left') {
        _leftPressed = pressed;
        widget.onButtonChange(widget.dpadLeftMask, pressed);
      } else if (direction == 'right') {
        _rightPressed = pressed;
        widget.onButtonChange(widget.dpadRightMask, pressed);
      }
    });

    if (pressed) {
      HapticService.instance.triggerButton();
    }
  }

  Widget _buildDpadArm({
    required IconData icon,
    required bool isPressed,
    required VoidCallback onTapDown,
    required VoidCallback onTapUp,
  }) {
    return GestureDetector(
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: () => onTapUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isPressed ? const Color(0xFF00C3E3) : const Color(0xFF2B2F3A),
          shape: BoxShape.circle,
          border: Border.all(
            color: isPressed ? Colors.white : const Color(0xFF3F4452),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (isPressed)
              BoxShadow(
                color: const Color(0xFF00C3E3).withValues(alpha: 0.5),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Icon(
          icon,
          color: isPressed ? Colors.black : Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center subtle cross base plate
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFF1B1E26),
              shape: BoxShape.circle,
            ),
          ),
          // Up
          Positioned(
            top: 0,
            child: _buildDpadArm(
              icon: Icons.keyboard_arrow_up_rounded,
              isPressed: _upPressed,
              onTapDown: () => _handlePress('up', true),
              onTapUp: () => _handlePress('up', false),
            ),
          ),
          // Down
          Positioned(
            bottom: 0,
            child: _buildDpadArm(
              icon: Icons.keyboard_arrow_down_rounded,
              isPressed: _downPressed,
              onTapDown: () => _handlePress('down', true),
              onTapUp: () => _handlePress('down', false),
            ),
          ),
          // Left
          Positioned(
            left: 0,
            child: _buildDpadArm(
              icon: Icons.keyboard_arrow_left_rounded,
              isPressed: _leftPressed,
              onTapDown: () => _handlePress('left', true),
              onTapUp: () => _handlePress('left', false),
            ),
          ),
          // Right
          Positioned(
            right: 0,
            child: _buildDpadArm(
              icon: Icons.keyboard_arrow_right_rounded,
              isPressed: _rightPressed,
              onTapDown: () => _handlePress('right', true),
              onTapUp: () => _handlePress('right', false),
            ),
          ),
        ],
      ),
    );
  }
}
