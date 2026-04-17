import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../services/app_constants.dart';
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
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isEmpty = false;
    });

    // Show a descriptive message only on first launch (backfill not yet done)
    final isFirstLaunch = !(await _db.hasPerformedBackfill());
    if (isFirstLaunch) {
      setState(() => _loadingMessage = 'Setting up your usage history…');
    }

    // Step 1: One-time historical backfill (30 days from OS)
    await _db.performHistoricalBackfill(_usageService);

    // Step 2: Fill gaps from days the app was not opened
    await _db.fillMissingDays(_usageService);

    setState(() => _loadingMessage = '');

    // Step 3: Fetch and store today's data (existing behaviour)
    await _fetchTodayUsage();
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
      for (final usage in usageList) {
        totalCO2 += usage['co2'] as double;
        totalEnergy += usage['energy'] as double;
      }

      final today = dateString(DateTime.now());
      await _db.insertOrUpdateDailyUsage(today, usageList);

      setState(() {
        _totalCO2 = totalCO2;
        _totalEnergy = totalEnergy;
      });
    } catch (e) {
      debugPrint('HomePage fetch error: $e');
      setState(() => _hasError = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Digital Carbon Footprint')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_loadingMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _loadingMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            )
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
