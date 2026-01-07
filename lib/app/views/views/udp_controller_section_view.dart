import 'package:flutter/material.dart';

import 'package:get/get.dart';

class UdpControllerSectionView extends GetView {
  const UdpControllerSectionView({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UdpControllerSectionView'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'UdpControllerSectionView is working',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
