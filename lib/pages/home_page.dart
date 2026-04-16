import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../widgets/carbon_circle.dart';
import '../widgets/error_display.dart';
import '../widgets/app_drawer.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final UsageService _usageService = UsageService();
  final DatabaseService _db = DatabaseService();

  double _totalCO2 = 0.0;
  double _totalEnergy = 0.0;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isEmpty = false;

  @override
  void initState() {
    super.initState();
    _fetchTodayUsage();
  }

  Future<void> _fetchTodayUsage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isEmpty = false;
    });
    try {
      final usageList = await _usageService.getTodayUsage();

      if (usageList.isEmpty) {
        setState(() => _isEmpty = true);
        return;
      }

      double totalCO2 = 0.0;
      double totalEnergy = 0.0;
      for (var usage in usageList) {
        totalCO2 += (usage['co2'] as double);
        totalEnergy += (usage['energy'] as double);
      }

      final today = _dateString(DateTime.now());
      await _db.insertOrUpdateDailyUsage(today, usageList);

      setState(() {
        _totalCO2 = totalCO2;
        _totalEnergy = totalEnergy;
      });
    } catch (e) {
      debugPrint('Error fetching usage: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
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
      appBar: AppBar(title: const Text('Digital Carbon Footprint')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? ErrorDisplay(
                  message: 'Unable to load usage data. Please check that '
                      'Usage Access permission is still granted.',
                  onRetry: _fetchTodayUsage,
                )
              : _isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_android,
                                size: 56, color: Colors.black26),
                            SizedBox(height: 16),
                            Text(
                              'No social media usage detected today.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 15, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Digital Carbon Footprint\nToday',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: screenWidth * 0.07,
                            ),
                          ),
                          const SizedBox(height: 30),
                          CarbonCircle(
                              co2Value: _totalCO2,
                              energyValue: _totalEnergy),
                        ],
                      ),
                    ),
    );
  }
}
