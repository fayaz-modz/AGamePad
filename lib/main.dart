import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/connection_provider.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/connection_page.dart';
import 'ui/pages/gamepad_page.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ],
      child: const AgamepadApp(),
    ),
  );
}

class AgamepadApp extends StatelessWidget {
  const AgamepadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGamepad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/connection': (context) => const ConnectionPage(),
        '/gamepad': (context) => const GamepadPage(),
      },
    );
  }
}
