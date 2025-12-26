import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/gamepad_layout.dart';
import '../../services/layout_storage_service.dart';
import '../widgets/bluetooth_status_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LayoutStorageService _storage = LayoutStorageService();
  List<GamepadLayout> _layouts = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _loadLayouts();
  }

  Future<void> _loadLayouts() async {
    final layouts = await _storage.loadLayouts();
    setState(() {
      _layouts = layouts;
    });
  }

  Future<void> _showRenameDialog(GamepadLayout layout) async {
    final controller = TextEditingController(text: layout.name);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final updatedLayout = GamepadLayout(
                  id: layout.id,
                  name: controller.text.trim(),
                  controls: layout.controls,
                );
                await _storage.saveLayout(updatedLayout);
                _loadLayouts();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteDialog(GamepadLayout layout) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Layout'),
        content: Text('Are you sure you want to delete "${layout.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _storage.deleteLayout(layout.id);
              _loadLayouts();
              if (context.mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AGamepad'),
      ),
      body: Column(
        children: [
          const BluetoothStatusCard(),
          Expanded(
            child: _layouts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _layouts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemBuilder: (context, index) {
                      final layout = _layouts[index];
                      // Check if it's one of our defaults
                      final isDefault = layout.id == 'xbox_default' || layout.id == 'android_default';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.gamepad),
                          title: Text(layout.name),
                          subtitle: Text(isDefault ? 'Default Layout' : 'Custom Layout'),
                          trailing: isDefault 
                              ? const Icon(Icons.chevron_right)
                              : PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'edit':
                                        await Navigator.pushNamed(
                                          context,
                                          '/gamepad',
                                          arguments: {'layout': layout, 'editMode': true},
                                        );
                                        _loadLayouts();
                                        break;
                                      case 'rename':
                                        _showRenameDialog(layout);
                                        break;
                                      case 'delete':
                                        _showDeleteDialog(layout);
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
                                          Icon(Icons.delete, size: 20, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                          onTap: () async {
                            await Navigator.pushNamed(
                              context,
                              '/gamepad',
                              arguments: isDefault ? layout : {'layout': layout, 'editMode': false},
                            );
                            _loadLayouts();
                          },
                        ),
                      );
                    },
                  ),
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
                const ListTile(title: Text('Create Custom Layout', style: TextStyle(fontWeight: FontWeight.bold))),
                ListTile(
                  leading: const Icon(Icons.gamepad),
                  title: const Text('Based on Xbox Style'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _createCustomLayout(GamepadLayout.xbox());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.android),
                  title: const Text('Based on Android Style'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _createCustomLayout(GamepadLayout.android());
                  },
                ),
                const SizedBox(height: 16),
              ],
            )
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
    
    await _storage.saveLayout(customLayout);
    _loadLayouts();
  }
}
