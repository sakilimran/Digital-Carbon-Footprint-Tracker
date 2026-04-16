import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../widgets/carbon_circle.dart';
import '../widgets/app_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UsageService _usageService = UsageService();
  final DatabaseService _db = DatabaseService();

  double _totalCO2 = 0.0; // in grams
  double _totalEnergy = 0.0; // in mAh
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTodayUsage();
  }

  Future<void> _fetchTodayUsage() async {
    try {
      final usageList = await _usageService.getTodayUsage();
      double totalCO2 = 0.0;
      double totalEnergy = 0.0;

      for (var usage in usageList) {
        totalCO2 += (usage['co2'] as double);
        totalEnergy += (usage['energy'] as double);
      }

      // Persist today's data to SQLite so historical screens and the
      // AI engine can read it without hitting the native layer again.
      if (usageList.isNotEmpty) {
        final today = _dateString(DateTime.now());
        await _db.insertOrUpdateDailyUsage(today, usageList);
      }

      setState(() {
        _totalCO2 = totalCO2;
        _totalEnergy = totalEnergy;
      });
    } catch (e) {
      debugPrint('Error fetching usage: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _dateString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Carbon Footprint'),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Responsive two-line title
                  Text(
                    "Digital Carbon Footprint\nToday",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: screenWidth * 0.07,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // The new CarbonCircle widget
                  CarbonCircle(co2Value: _totalCO2, energyValue: _totalEnergy),
                ],
              ),
            ),
    );
  }
}
