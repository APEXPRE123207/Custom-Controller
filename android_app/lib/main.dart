import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/controller_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const NintendoControllerApp());
}

class NintendoControllerApp extends StatelessWidget {
  const NintendoControllerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nintendo Pro Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C3E3),
          secondary: Color(0xFFFF4554),
          surface: Color(0xFF191C24),
        ),
      ),
      home: const ControllerScreen(),
    );
  }
}
