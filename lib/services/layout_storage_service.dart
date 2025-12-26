import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gamepad_layout.dart';

class LayoutStorageService {
  static const String keyLayouts = 'custom_layouts';

  Future<List<GamepadLayout>> loadLayouts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(keyLayouts);

    List<GamepadLayout> layouts = [
      GamepadLayout.xbox(),
      GamepadLayout.android(),
    ];

    if (jsonList != null) {
      layouts.addAll(jsonList.map((str) => GamepadLayout.fromJson(jsonDecode(str))));
    }
    return layouts;
  }

  Future<void> saveLayout(GamepadLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    List<GamepadLayout> current = await loadLayouts();
    
    // Remove if exists (update)
    current.removeWhere((l) => l.id == layout.id);
    // Don't duplicate defaults
    if (layout.id != 'xbox_default' && layout.id != 'android_default') {
      current.add(layout);
    }

    // Filter out defaults from persistence list
    List<String> jsonList = current
        .where((l) => l.id != 'xbox_default' && l.id != 'android_default')
        .map((l) => jsonEncode(l.toJson()))
        .toList();
    
    await prefs.setStringList(keyLayouts, jsonList);
  }

  Future<void> deleteLayout(String layoutId) async {
    final prefs = await SharedPreferences.getInstance();
    List<GamepadLayout> current = await loadLayouts();
    
    // Remove the layout
    current.removeWhere((l) => l.id == layoutId);
    
    // Filter out defaults from persistence list
    List<String> jsonList = current
        .where((l) => l.id != 'xbox_default' && l.id != 'android_default')
        .map((l) => jsonEncode(l.toJson()))
        .toList();
    
    await prefs.setStringList(keyLayouts, jsonList);
  }
}
