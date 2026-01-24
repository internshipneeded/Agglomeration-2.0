import 'package:flutter/material.dart';
import 'package:pet_perplexity/features/onboarding/splash/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PET Perplexity',
      home: SplashScreen(),
    );
  }
}