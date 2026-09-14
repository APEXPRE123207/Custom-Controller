import 'dart:convert';

/// Represents position and scale of a customizable controller element.
class ElementLayout {
  double x; // Fractional X position (0.0 to 1.0)
  double y; // Fractional Y position (0.0 to 1.0)
  double scale; // Scaling factor (0.7 to 1.5)

  ElementLayout({
    required this.x,
    required this.y,
    this.scale = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'scale': scale,
      };

  factory ElementLayout.fromJson(Map<String, dynamic> json) => ElementLayout(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      );

  ElementLayout copyWith({double? x, double? y, double? scale}) {
    return ElementLayout(
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
    );
  }
}

/// Stores all customizable element layouts on the screen.
class ControllerLayoutConfig {
  ElementLayout leftStick;
  ElementLayout dpad;
  ElementLayout rightStick;
  ElementLayout actionButtons;
  ElementLayout leftTriggers;
  ElementLayout rightTriggers;
  ElementLayout centerButtons;

  ControllerLayoutConfig({
    required this.leftStick,
    required this.dpad,
    required this.rightStick,
    required this.actionButtons,
    required this.leftTriggers,
    required this.rightTriggers,
    required this.centerButtons,
  });

  /// Default ergonomic Nintendo Switch Pro layout
  factory ControllerLayoutConfig.defaultLayout() {
    return ControllerLayoutConfig(
      leftStick: ElementLayout(x: 0.12, y: 0.55, scale: 1.0),
      dpad: ElementLayout(x: 0.30, y: 0.55, scale: 1.0),
      rightStick: ElementLayout(x: 0.70, y: 0.55, scale: 1.0),
      actionButtons: ElementLayout(x: 0.88, y: 0.55, scale: 1.0),
      leftTriggers: ElementLayout(x: 0.14, y: 0.08, scale: 1.0),
      rightTriggers: ElementLayout(x: 0.86, y: 0.08, scale: 1.0),
      centerButtons: ElementLayout(x: 0.50, y: 0.50, scale: 1.0),
    );
  }

  Map<String, dynamic> toJson() => {
        'leftStick': leftStick.toJson(),
        'dpad': dpad.toJson(),
        'rightStick': rightStick.toJson(),
        'actionButtons': actionButtons.toJson(),
        'leftTriggers': leftTriggers.toJson(),
        'rightTriggers': rightTriggers.toJson(),
        'centerButtons': centerButtons.toJson(),
      };

  factory ControllerLayoutConfig.fromJson(Map<String, dynamic> json) {
    final def = ControllerLayoutConfig.defaultLayout();
    return ControllerLayoutConfig(
      leftStick: json['leftStick'] != null ? ElementLayout.fromJson(json['leftStick']) : def.leftStick,
      dpad: json['dpad'] != null ? ElementLayout.fromJson(json['dpad']) : def.dpad,
      rightStick: json['rightStick'] != null ? ElementLayout.fromJson(json['rightStick']) : def.rightStick,
      actionButtons: json['actionButtons'] != null ? ElementLayout.fromJson(json['actionButtons']) : def.actionButtons,
      leftTriggers: json['leftTriggers'] != null ? ElementLayout.fromJson(json['leftTriggers']) : def.leftTriggers,
      rightTriggers: json['rightTriggers'] != null ? ElementLayout.fromJson(json['rightTriggers']) : def.rightTriggers,
      centerButtons: json['centerButtons'] != null ? ElementLayout.fromJson(json['centerButtons']) : def.centerButtons,
    );
  }

  String serialize() => jsonEncode(toJson());

  static ControllerLayoutConfig? deserialize(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ControllerLayoutConfig.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}
