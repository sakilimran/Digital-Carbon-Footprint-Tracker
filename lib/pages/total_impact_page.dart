import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../widgets/carbon_circle.dart';
import '../widgets/app_drawer.dart';

class TotalImpactPage extends StatefulWidget {
  const TotalImpactPage({Key? key}) : super(key: key);

  @override
  State<TotalImpactPage> createState() => _TotalImpactPageState();
}

class _TotalImpactPageState extends State<TotalImpactPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UsageService _usageService = UsageService();
  final DatabaseService _db = DatabaseService();

  double _dailyImpact = 0.0;
  double _monthlyImpact = 0.0;
  double _yearlyImpact = 0.0;

  double _dailyEnergyImpact = 0.0;
  double _monthlyEnergyImpact = 0.0;
  double _yearlyEnergyImpact = 0.0;

  bool _loadingDaily = true;
  bool _loadingMonthly = true;
  bool _loadingYearly = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    await _fetchYearlyImpact();
    await _fetchMonthlyImpact();
    await _fetchDailyImpact();
  }

  /// Returns aggregated usage for a date range.
  /// Tries SQLite first; falls back to the native API if no stored data exists.
  Future<List<Map<String, dynamic>>> _getUsageForRange(
      DateTime start, DateTime end) async {
    final startStr = _dateString(start);
    final endStr = _dateString(end);

    final stored = await _db.getAggregatedUsageForRange(startStr, endStr);
    if (stored.isNotEmpty) return stored;

    return _usageService.getRangeUsage(start: start, end: end);
  }

  double _sumCO2(List<Map<String, dynamic>> data) =>
      data.fold(0.0, (sum, item) => sum + (item['co2'] as double));

  double _sumEnergy(List<Map<String, dynamic>> data) =>
      data.fold(0.0, (sum, item) => sum + (item['energy'] as double));

  Future<void> _fetchYearlyImpact() async {
    try {
      final now = DateTime.now();
      final startThisYear = DateTime(now.year, 1, 1);
      final startLastYear = DateTime(now.year - 1, 1, 1);
      final endLastYear = DateTime(now.year - 1, 12, 31, 23, 59, 59);

      final thisYearData = await _getUsageForRange(startThisYear, now);
      final lastYearData = await _getUsageForRange(startLastYear, endLastYear);

      setState(() {
        _yearlyImpact = _sumCO2(thisYearData) - _sumCO2(lastYearData);
        _yearlyEnergyImpact = _sumEnergy(thisYearData) - _sumEnergy(lastYearData);
      });
    } catch (e) {
      debugPrint('Error fetching yearly impact: $e');
    } finally {
      setState(() => _loadingYearly = false);
    }
  }

  Future<void> _fetchMonthlyImpact() async {
    try {
      final now = DateTime.now();
      final startThisMonth = DateTime(now.year, now.month, 1);
      final startLastMonth = DateTime(now.year, now.month - 1, 1);
      final endLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

      final thisMonthData = await _getUsageForRange(startThisMonth, now);
      final lastMonthData = await _getUsageForRange(startLastMonth, endLastMonth);

      setState(() {
        _monthlyImpact = _sumCO2(thisMonthData) - _sumCO2(lastMonthData);
        _monthlyEnergyImpact = _sumEnergy(thisMonthData) - _sumEnergy(lastMonthData);
      });
    } catch (e) {
      debugPrint('Error fetching monthly impact: $e');
    } finally {
      setState(() => _loadingMonthly = false);
    }
  }

  Future<void> _fetchDailyImpact() async {
    try {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final startYesterday = startToday.subtract(const Duration(days: 1));
      final endYesterday = startToday.subtract(const Duration(seconds: 1));

      final todayData = await _getUsageForRange(startToday, now);
      final yesterdayData = await _getUsageForRange(startYesterday, endYesterday);

      setState(() {
        _dailyImpact = _sumCO2(todayData) - _sumCO2(yesterdayData);
        _dailyEnergyImpact = _sumEnergy(todayData) - _sumEnergy(yesterdayData);
      });
    } catch (e) {
      debugPrint('Error fetching daily impact: $e');
    } finally {
      setState(() => _loadingDaily = false);
    }
  }

  String _dateString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Impact'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Monthly'),
            Tab(text: 'Yearly'),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabContent(_dailyImpact, _dailyEnergyImpact, _loadingDaily),
          _buildTabContent(_monthlyImpact, _monthlyEnergyImpact, _loadingMonthly),
          _buildTabContent(_yearlyImpact, _yearlyEnergyImpact, _loadingYearly),
        ],
      ),
    );
  }

  /// Helper to build each tab's content based on data + loading flags
  Widget _buildTabContent(double impact, double energyImpact, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: CarbonCircle(co2Value: impact, energyValue: energyImpact),
    );
  }
}
