import 'package:flutter/material.dart';
import 'services/app_constants.dart';
import 'pages/home_page.dart';
import 'pages/stats_page.dart';
import 'pages/total_impact_page.dart';
import 'pages/recommendations_page.dart';
import 'pages/data_management_page.dart';
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
      title: 'Digital Carbon Footprint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Titillium',
        scaffoldBackgroundColor: kPrimaryGreen,
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PermissionCheckScreen(),
        '/home': (context) => const HomePage(),
        '/stats': (context) => const StatsPage(),
        '/totalImpact': (context) => const TotalImpactPage(),
        '/recommendations': (context) => const RecommendationsPage(),
        '/dataManagement': (context) => const DataManagementPage(),
        '/about': (context) => const AboutPage(),
      },
    );
  }
}
