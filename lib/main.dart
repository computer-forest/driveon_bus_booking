import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/splash_screen.dart';

void main() {
  runApp(const CharterBookingApp());
}

class CharterBookingApp extends StatelessWidget {
  const CharterBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charter Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
