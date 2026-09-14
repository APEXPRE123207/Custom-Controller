import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class NintendoCenterButton extends StatefulWidget {
  final IconData? icon;
  final String? text;
  final int buttonMask;
  final Function(int mask, bool pressed) onButtonChange;
  final bool isSquare; // Capture button is square

  const NintendoCenterButton({
    super.key,
    this.icon,
    this.text,
    required this.buttonMask,
    required this.onButtonChange,
    this.isSquare = false,
  });

  @override
  State<NintendoCenterButton> createState() => _NintendoCenterButtonState();
}

class _NintendoCenterButtonState extends State<NintendoCenterButton> {
  bool _isPressed = false;

  void _handlePress(bool pressed) {
    setState(() {
      _isPressed = pressed;
    });
    widget.onButtonChange(widget.buttonMask, pressed);
    if (pressed) {
      HapticService.instance.triggerButton();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _handlePress(true),
      onTapUp: (_) => _handlePress(false),
      onTapCancel: () => _handlePress(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _isPressed ? const Color(0xFFE2E6EF) : const Color(0xFF272A34),
          shape: widget.isSquare ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: widget.isSquare ? BorderRadius.circular(6) : null,
          border: Border.all(
            color: _isPressed ? Colors.white : const Color(0xFF434857),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: widget.icon != null
              ? Icon(
                  widget.icon,
                  color: _isPressed ? Colors.black : Colors.white70,
                  size: 16,
                )
              : Text(
                  widget.text ?? '',
                  style: TextStyle(
                    color: _isPressed ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
        ),
      ),
    );
  }
}
