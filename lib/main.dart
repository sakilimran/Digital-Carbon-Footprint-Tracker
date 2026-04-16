// lib/main.dart

import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/stats_page.dart';
import 'pages/total_impact_page.dart';
import 'pages/recommendations_page.dart';
import 'pages/about_page.dart';
import 'screens/permission_check_screen.dart';

void main() {
  runApp(const SocialMediaCarbonFootprintApp());
}

class SocialMediaCarbonFootprintApp extends StatelessWidget {
  const SocialMediaCarbonFootprintApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Media Carbon Footprint',
      theme: ThemeData(
        fontFamily: 'Titillium',
        scaffoldBackgroundColor: const Color(0xFFB3D48E),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // We start by checking usage permission
      initialRoute: '/',
      routes: {
        // Step 1: Permission check
        '/': (context) => const PermissionCheckScreen(),

        // Step 2: If granted, go to real home
        '/home': (context) => const HomePage(),
        '/stats': (context) => const StatsPage(),
        '/totalImpact': (context) => const TotalImpactPage(),
        '/recommendations': (context) => const RecommendationsPage(),
        '/about': (context) => const AboutPage(),
      },
    );
  }
}
