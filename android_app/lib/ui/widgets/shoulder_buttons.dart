import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class NintendoShoulderButton extends StatefulWidget {
  final String label;
  final int buttonMask;
  final Function(int mask, bool pressed) onButtonChange;
  final Color accentColor;
  final bool isTrigger; // ZL or ZR

  const NintendoShoulderButton({
    super.key,
    required this.label,
    required this.buttonMask,
    required this.onButtonChange,
    required this.accentColor,
    this.isTrigger = false,
  });

  @override
  State<NintendoShoulderButton> createState() => _NintendoShoulderButtonState();
}

class _NintendoShoulderButtonState extends State<NintendoShoulderButton> {
  bool _isPressed = false;

  void _handlePress(bool pressed) {
    setState(() {
      _isPressed = pressed;
    });
    widget.onButtonChange(widget.buttonMask, pressed);
    if (pressed) {
      if (widget.isTrigger) {
        HapticService.instance.triggerHeavy();
      } else {
        HapticService.instance.triggerButton();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.isTrigger ? 88.0 : 76.0;
    final height = widget.isTrigger ? 42.0 : 36.0;

    return GestureDetector(
      onTapDown: (_) => _handlePress(true),
      onTapUp: (_) => _handlePress(false),
      onTapCancel: () => _handlePress(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _isPressed ? widget.accentColor : const Color(0xFF222630),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(widget.label.startsWith('Z') ? 14 : 10),
            topRight: Radius.circular(widget.label.startsWith('Z') ? 14 : 10),
            bottomLeft: const Radius.circular(6),
            bottomRight: const Radius.circular(6),
          ),
          border: Border.all(
            color: _isPressed ? Colors.white : const Color(0xFF3B404D),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (_isPressed)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.6),
                blurRadius: 8,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              color: _isPressed ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: widget.isTrigger ? 14 : 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
