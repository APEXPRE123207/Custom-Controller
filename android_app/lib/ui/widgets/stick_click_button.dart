import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class NintendoStickClickButton extends StatefulWidget {
  final String label;
  final int buttonMask;
  final Function(int mask, bool pressed) onButtonChange;
  final Color accentColor;

  const NintendoStickClickButton({
    super.key,
    required this.label,
    required this.buttonMask,
    required this.onButtonChange,
    required this.accentColor,
  });

  @override
  State<NintendoStickClickButton> createState() => _NintendoStickClickButtonState();
}

class _NintendoStickClickButtonState extends State<NintendoStickClickButton> {
  bool _isPressed = false;

  void _handlePress(bool pressed) {
    setState(() {
      _isPressed = pressed;
    });
    widget.onButtonChange(widget.buttonMask, pressed);
    if (pressed) {
      HapticService.instance.triggerHeavy();
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: _isPressed ? widget.accentColor : const Color(0xFF222630),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPressed ? Colors.white : widget.accentColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
            if (_isPressed)
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.7),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.radio_button_checked,
              size: 13,
              color: _isPressed ? Colors.black : widget.accentColor,
            ),
            const SizedBox(width: 5),
            Text(
              widget.label,
              style: TextStyle(
                color: _isPressed ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
