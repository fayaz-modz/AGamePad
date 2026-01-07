import 'package:agamepad/app/components/bluetooth_status_card.dart';
import 'package:agamepad/app/data/models/gamepad_layout.dart';
import 'package:agamepad/app/routes/app_pages.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AGamepad')),
      body: Column(
        children: [
          const BluetoothStatusCard(),
          Expanded(
            child: Obx(() {
              return controller.layouts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: controller.layouts.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        final layout = controller.layouts[index];
                        // Check if it's one of our defaults
                        final isDefault =
                            layout.id == 'xbox_default' ||
                            layout.id == 'android_default';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.gamepad),
                            title: Text(layout.name),
                            subtitle: Text(
                              isDefault ? 'Default Layout' : 'Custom Layout',
                            ),
                            trailing: isDefault
                                ? const Icon(Icons.chevron_right)
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) async {
                                      switch (value) {
                                        case 'edit':
                                          await Get.toNamed(
                                            Routes.GAMEPAD,
                                            arguments: {
                                              'layout': layout,
                                              'editMode': true,
                                            },
                                          );
                                          controller.loadLayouts();
                                          break;
                                        case 'rename':
                                          controller.showRenameDialog(layout);
                                          break;
                                        case 'delete':
                                          controller.showDeleteDialog(layout);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'rename',
                                        child: Row(
                                          children: [
                                            Icon(Icons.text_fields, size: 20),
                                            SizedBox(width: 8),
                                            Text('Rename'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                            onTap: () async {
                              await Get.toNamed(
                                Routes.GAMEPAD,
                                arguments: isDefault
                                    ? layout
                                    : {'layout': layout, 'editMode': false},
                              );
                              controller.loadLayouts();
                            },
                          ),
                        );
                      },
                    );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Create Custom Layout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.gamepad),
                  title: const Text('Based on Xbox Style'),
                  onTap: () async {
                    Get.back();
                    await _createCustomLayout(GamepadLayout.xbox());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.android),
                  title: const Text('Based on Android Style'),
                  onTap: () async {
                    Get.back();
                    await _createCustomLayout(GamepadLayout.android());
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _createCustomLayout(GamepadLayout template) async {
    final customLayout = GamepadLayout(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Custom ${template.name}',
      controls: template.controls.map((c) => c.copyWith()).toList(),
    );

    await controller.storage.saveLayout(customLayout);
    controller.loadLayouts();
  }
}
