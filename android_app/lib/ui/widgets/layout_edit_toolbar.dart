import 'package:flutter/material.dart';
import '../../services/layout_service.dart';

class LayoutEditToolbar extends StatelessWidget {
  const LayoutEditToolbar({super.key});

  String _getFriendlyName(String key) {
    switch (key) {
      case 'leftStick':
        return 'Left Stick (W/A/S/D)';
      case 'dpad':
        return 'D-Pad';
      case 'rightStick':
        return 'Right Stick (I/J/K/L)';
      case 'actionButtons':
        return 'Actions (A/B/X/Y)';
      case 'leftTriggers':
        return 'Triggers (ZL/L)';
      case 'rightTriggers':
        return 'Triggers (ZR/R)';
      case 'centerButtons':
        return 'Center (+/-/Home)';
      default:
        return 'Selected Button';
    }
  }

  @override
  Widget build(BuildContext context) {
    final layoutService = LayoutService.instance;
    final selectedKey = layoutService.selectedElement;
    final elementLayout = layoutService.getElement(selectedKey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141720).withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF00E676), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Selected item badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676), width: 1),
              ),
              child: Text(
                _getFriendlyName(selectedKey),
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Scale slider
            const Text(
              "Size:",
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF00E676),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: const Color(0xFF00E676),
                  overlayColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                ),
                child: Slider(
                  value: elementLayout.scale,
                  min: 0.7,
                  max: 1.5,
                  divisions: 16,
                  label: "${(elementLayout.scale * 100).toInt()}%",
                  onChanged: (val) {
                    layoutService.updateScale(selectedKey, val);
                  },
                ),
              ),
            ),
            Text(
              "${(elementLayout.scale * 100).toInt()}%",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 14),

            // Reset button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white30),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Reset', style: TextStyle(fontSize: 11)),
              onPressed: () {
                layoutService.resetToDefaults();
              },
            ),
            const SizedBox(width: 8),

            // Save & Done button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Save & Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                layoutService.saveLayout();
                layoutService.toggleEditMode(false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
