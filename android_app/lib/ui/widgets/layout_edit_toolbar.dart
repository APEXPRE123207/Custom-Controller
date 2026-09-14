import 'package:flutter/material.dart';
import '../../services/layout_service.dart';

class LayoutEditToolbar extends StatelessWidget {
  const LayoutEditToolbar({super.key});

  static const List<MapEntry<String, String>> elements = [
    MapEntry('leftStick', '🕹️ Left Stick (W/A/S/D)'),
    MapEntry('dpad', '🎯 D-Pad (Arrows)'),
    MapEntry('rightStick', '🕹️ Right Stick (I/J/K/L)'),
    MapEntry('actionButtons', '🔴 Actions (A/B/X/Y)'),
    MapEntry('leftTriggers', '⚡ Triggers (ZL/L)'),
    MapEntry('rightTriggers', '⚡ Triggers (ZR/R)'),
    MapEntry('centerButtons', '🔘 Center (+/-/Home)'),
  ];

  void _cycleElement(LayoutService layoutService, int delta) {
    final currentIndex = elements.indexWhere((e) => e.key == layoutService.selectedElement);
    if (currentIndex == -1) return;
    final nextIndex = (currentIndex + delta + elements.length) % elements.length;
    layoutService.selectElement(elements[nextIndex].key);
  }

  @override
  Widget build(BuildContext context) {
    final layoutService = LayoutService.instance;
    final selectedKey = layoutService.selectedElement;
    final elementLayout = layoutService.getElement(selectedKey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF141720).withValues(alpha: 0.96),
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
            // Cycle backward button
            IconButton(
              tooltip: 'Previous button',
              icon: const Icon(Icons.arrow_left_rounded, color: Color(0xFF00E676), size: 24),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _cycleElement(layoutService, -1),
            ),

            // Dropdown element selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00E676), width: 1.2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: elements.any((e) => e.key == selectedKey) ? selectedKey : elements.first.key,
                  dropdownColor: const Color(0xFF1B1F2A),
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF00E676), size: 20),
                  items: elements.map((e) {
                    return DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      layoutService.selectElement(val);
                    }
                  },
                ),
              ),
            ),

            // Cycle forward button
            IconButton(
              tooltip: 'Next button',
              icon: const Icon(Icons.arrow_right_rounded, color: Color(0xFF00E676), size: 24),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _cycleElement(layoutService, 1),
            ),
            const SizedBox(width: 8),

            // Scale slider
            const Text(
              "Size:",
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF00E676),
                  inactiveTrackColor: Colors.white24,
                  thumbColor: const Color(0xFF00E676),
                  overlayColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),

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
            const SizedBox(width: 6),

            // Save & Done button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.check_rounded, size: 15),
              label: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
