import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/layout_config.dart';

/// Manages customization of button positions and sizes.
class LayoutService extends ChangeNotifier {
  static final LayoutService instance = LayoutService._internal();
  LayoutService._internal() {
    loadLayout();
  }

  ControllerLayoutConfig config = ControllerLayoutConfig.defaultLayout();
  bool isEditMode = false;
  String selectedElement = 'actionButtons'; // Default selection for scaling

  void toggleEditMode(bool enable) {
    isEditMode = enable;
    notifyListeners();
  }

  void selectElement(String key) {
    selectedElement = key;
    notifyListeners();
  }

  ElementLayout getElement(String key) {
    switch (key) {
      case 'leftStick':
        return config.leftStick;
      case 'dpad':
        return config.dpad;
      case 'rightStick':
        return config.rightStick;
      case 'actionButtons':
        return config.actionButtons;
      case 'leftTriggers':
        return config.leftTriggers;
      case 'rightTriggers':
        return config.rightTriggers;
      case 'centerButtons':
        return config.centerButtons;
      default:
        return config.actionButtons;
    }
  }

  void updatePosition(String key, double x, double y) {
    final clampedX = x.clamp(0.05, 0.95);
    final clampedY = y.clamp(0.05, 0.95);

    switch (key) {
      case 'leftStick':
        config.leftStick = config.leftStick.copyWith(x: clampedX, y: clampedY);
        break;
      case 'dpad':
        config.dpad = config.dpad.copyWith(x: clampedX, y: clampedY);
        break;
      case 'rightStick':
        config.rightStick = config.rightStick.copyWith(x: clampedX, y: clampedY);
        break;
      case 'actionButtons':
        config.actionButtons = config.actionButtons.copyWith(x: clampedX, y: clampedY);
        break;
      case 'leftTriggers':
        config.leftTriggers = config.leftTriggers.copyWith(x: clampedX, y: clampedY);
        break;
      case 'rightTriggers':
        config.rightTriggers = config.rightTriggers.copyWith(x: clampedX, y: clampedY);
        break;
      case 'centerButtons':
        config.centerButtons = config.centerButtons.copyWith(x: clampedX, y: clampedY);
        break;
    }
    notifyListeners();
  }

  void updateScale(String key, double scale) {
    final clampedScale = scale.clamp(0.65, 1.6);
    switch (key) {
      case 'leftStick':
        config.leftStick = config.leftStick.copyWith(scale: clampedScale);
        break;
      case 'dpad':
        config.dpad = config.dpad.copyWith(scale: clampedScale);
        break;
      case 'rightStick':
        config.rightStick = config.rightStick.copyWith(scale: clampedScale);
        break;
      case 'actionButtons':
        config.actionButtons = config.actionButtons.copyWith(scale: clampedScale);
        break;
      case 'leftTriggers':
        config.leftTriggers = config.leftTriggers.copyWith(scale: clampedScale);
        break;
      case 'rightTriggers':
        config.rightTriggers = config.rightTriggers.copyWith(scale: clampedScale);
        break;
      case 'centerButtons':
        config.centerButtons = config.centerButtons.copyWith(scale: clampedScale);
        break;
    }
    notifyListeners();
  }

  void resetToDefaults() {
    config = ControllerLayoutConfig.defaultLayout();
    saveLayout();
    notifyListeners();
  }

  Future<void> saveLayout() async {
    try {
      final file = _getStorageFile();
      if (file != null) {
        await file.writeAsString(config.serialize());
      }
    } catch (e) {
      debugPrint("Error saving layout: $e");
    }
  }

  Future<void> loadLayout() async {
    try {
      final file = _getStorageFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final loaded = ControllerLayoutConfig.deserialize(content);
        if (loaded != null) {
          config = loaded;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Error loading layout: $e");
    }
  }

  File? _getStorageFile() {
    try {
      final path = Platform.isAndroid
          ? '/data/user/0/com.nintendo.controller.nintendo_pro_controller/files/layout.json'
          : 'custom_layout.json';
      final file = File(path);
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      return file;
    } catch (_) {
      return null;
    }
  }
}
