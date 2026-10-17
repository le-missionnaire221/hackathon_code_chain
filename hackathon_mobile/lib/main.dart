import 'package:flutter/material.dart';
import 'core/constants/app_theme.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  runApp(const CodeChainFintechApp());
}

class CodeChainFintechApp extends StatelessWidget {
  const CodeChainFintechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Code & Chain - Lightning Fintech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}
