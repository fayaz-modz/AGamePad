import 'package:agamepad/app/data/models/gamepad_layout.dart';
import 'package:agamepad/app/data/services/layout_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  final LayoutStorageService storage = LayoutStorageService();
  RxList<GamepadLayout> layouts = <GamepadLayout>[].obs;

  final count = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadLayouts();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  Future<void> loadLayouts() async {
    layouts.value = await storage.loadLayouts();
    debugPrint("loaded layouts");
  }

  Future<void> showRenameDialog(GamepadLayout layout) async {
    final controller = TextEditingController(text: layout.name);

    return Get.dialog(
      AlertDialog(
        title: const Text('Rename Layout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Layout Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final updatedLayout = GamepadLayout(
                  id: layout.id,
                  name: controller.text.trim(),
                  controls: layout.controls,
                );
                await storage.saveLayout(updatedLayout);
                loadLayouts();
                Get.back();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> showDeleteDialog(GamepadLayout layout) async {
    return Get.dialog(
      AlertDialog(
        title: const Text('Delete Layout'),
        content: Text('Are you sure you want to delete "${layout.name}"?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await storage.deleteLayout(layout.id);
              loadLayouts();
              Get.back();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void increment() => count.value++;
}
