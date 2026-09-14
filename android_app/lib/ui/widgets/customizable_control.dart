import 'package:flutter/material.dart';
import '../../models/layout_config.dart';
import '../../services/layout_service.dart';

class CustomizableControl extends StatelessWidget {
  final String elementKey;
  final String label;
  final Widget child;
  final BoxConstraints screenConstraints;

  const CustomizableControl({
    super.key,
    required this.elementKey,
    required this.label,
    required this.child,
    required this.screenConstraints,
  });

  @override
  Widget build(BuildContext context) {
    final layoutService = LayoutService.instance;
    final isEditMode = layoutService.isEditMode;
    final isSelected = layoutService.selectedElement == elementKey;
    final ElementLayout layout = layoutService.getElement(elementKey);

    final screenWidth = screenConstraints.maxWidth;
    final screenHeight = screenConstraints.maxHeight;

    // Convert fractional position to screen pixels (anchored at center of widget)
    final posX = layout.x * screenWidth;
    final posY = layout.y * screenHeight;

    Widget controlBody = Transform.scale(
      scale: layout.scale,
      child: child,
    );

    if (isEditMode) {
      controlBody = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          layoutService.selectElement(elementKey);
        },
        onPanUpdate: (details) {
          final newPixelX = posX + details.delta.dx;
          final newPixelY = posY + details.delta.dy;
          layoutService.updatePosition(
            elementKey,
            newPixelX / screenWidth,
            newPixelY / screenHeight,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFF00E676) : const Color(0xFF00C3E3).withValues(alpha: 0.6),
              width: isSelected ? 2.5 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? const Color(0xFF00E676).withValues(alpha: 0.15)
                : const Color(0xFF00C3E3).withValues(alpha: 0.08),
          ),
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Ignore pointers for child in edit mode so gestures are caught by dragger
              IgnorePointer(child: controlBody),

              // Element tag badge
              Positioned(
                top: -14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF00E676) : const Color(0xFF1E222D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white30,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "$label (${(layout.scale * 100).toInt()}%)",
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Positioned(
      left: posX,
      top: posY,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5), // Center anchor
        child: controlBody,
      ),
    );
  }
}
