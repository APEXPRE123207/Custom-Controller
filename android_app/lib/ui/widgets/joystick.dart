import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';

class VirtualJoystick extends StatefulWidget {
  final double size;
  final String label;
  final ValueChanged<Offset> onDirectionChanged;
  final VoidCallback? onStickClick;
  final Color accentColor;

  const VirtualJoystick({
    super.key,
    this.size = 140.0,
    required this.label,
    required this.onDirectionChanged,
    this.onStickClick,
    this.accentColor = const Color(0xFF00C3E3), // Neon Cyan/Blue default
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _dragPosition = Offset.zero;
  bool _isPressed = false;
  DateTime _lastTickTime = DateTime.now();

  void _updateOffset(Offset localPosition) {
    final center = Offset(widget.size / 2, widget.size / 2);
    final delta = localPosition - center;
    final maxRadius = (widget.size / 2) - 22;

    Offset clampedDelta;
    if (delta.distance > maxRadius) {
      clampedDelta = Offset.fromDirection(delta.direction, maxRadius);
    } else {
      clampedDelta = delta;
    }

    setState(() {
      _dragPosition = clampedDelta;
    });

    // Deadzone filter
    final normalizedX = (clampedDelta.dx / maxRadius).clamp(-1.0, 1.0);
    final normalizedY = (clampedDelta.dy / maxRadius).clamp(-1.0, 1.0);

    final filteredX = normalizedX.abs() < 0.12 ? 0.0 : normalizedX;
    final filteredY = normalizedY.abs() < 0.12 ? 0.0 : normalizedY;

    widget.onDirectionChanged(Offset(filteredX, filteredY));

    // Subtle tick on outer edge hit
    if (delta.distance >= maxRadius && DateTime.now().difference(_lastTickTime).inMilliseconds > 180) {
      HapticService.instance.triggerTick();
      _lastTickTime = DateTime.now();
    }
  }

  void _reset() {
    setState(() {
      _dragPosition = Offset.zero;
      _isPressed = false;
    });
    widget.onDirectionChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    const thumbRadius = 26.0;

    return GestureDetector(
      onPanStart: (details) {
        _isPressed = true;
        _updateOffset(details.localPosition);
      },
      onPanUpdate: (details) {
        _updateOffset(details.localPosition);
      },
      onPanEnd: (_) => _reset(),
      onPanCancel: () => _reset(),
      onDoubleTap: () {
        HapticService.instance.triggerHeavy();
        widget.onStickClick?.call();
      },
      child: RepaintBoundary(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E2129),
            border: Border.all(
              color: _isPressed ? widget.accentColor.withValues(alpha: 0.8) : const Color(0xFF333842),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
              if (_isPressed)
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Directional Cross indicators inside base
              Positioned(
                top: 8,
                child: Container(width: 4, height: 8, color: Colors.white24),
              ),
              Positioned(
                bottom: 8,
                child: Container(width: 4, height: 8, color: Colors.white24),
              ),
              Positioned(
                left: 8,
                child: Container(width: 8, height: 4, color: Colors.white24),
              ),
              Positioned(
                right: 8,
                child: Container(width: 8, height: 4, color: Colors.white24),
              ),

              // Analog Thumb Cap
              Transform.translate(
                offset: _dragPosition,
                child: Container(
                  width: thumbRadius * 2,
                  height: thumbRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFF424754),
                        Color(0xFF262A34),
                        Color(0xFF181A20),
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.6),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
