import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../services/app_constants.dart';
import '../widgets/carbon_circle.dart';
import '../widgets/error_display.dart';
import '../widgets/app_drawer.dart';

/// Shows the cumulative CO₂ and energy impact for three time windows:
///   Daily   — total generated today (midnight → now)
///   Monthly — total generated this calendar month (1st → now)
///   Yearly  — total generated this calendar year (Jan 1 → now)
///
/// Each tab is independent: a fetch failure in one period does not affect
/// the others, and each has its own retry button.
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

  double _dailyCO2 = 0.0;
  double _monthlyCO2 = 0.0;
  double _yearlyCO2 = 0.0;

  double _dailyEnergy = 0.0;
  double _monthlyEnergy = 0.0;
  double _yearlyEnergy = 0.0;

  bool _loadingDaily = true;
  bool _loadingMonthly = true;
  bool _loadingYearly = true;

  bool _errorDaily = false;
  bool _errorMonthly = false;
  bool _errorYearly = false;

  bool _emptyDaily = false;
  bool _emptyMonthly = false;
  bool _emptyYearly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.wait([
      _fetchDaily(),
      _fetchMonthly(),
      _fetchYearly(),
    ]).ignore();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Data fetching — SQLite first, native API fallback
  // -------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _getForRange(
      DateTime start, DateTime end) async {
    final stored = await _db.getAggregatedUsageForRange(
        dateString(start), dateString(end));
    if (stored.isNotEmpty) return stored;
    return _usageService.getRangeUsage(start: start, end: end);
  }

  double _sumCO2(List<Map<String, dynamic>> data) =>
      data.fold(0.0, (s, d) => s + (d['co2'] as double));

  double _sumEnergy(List<Map<String, dynamic>> data) =>
      data.fold(0.0, (s, d) => s + (d['energy'] as double));

  /// Today's total: midnight → now.
  Future<void> _fetchDaily() async {
    setState(() {
      _loadingDaily = true;
      _errorDaily = false;
      _emptyDaily = false;
    });
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final data = await _getForRange(startOfDay, now);

      if (data.isEmpty) {
        setState(() => _emptyDaily = true);
        return;
      }
      setState(() {
        _dailyCO2 = _sumCO2(data);
        _dailyEnergy = _sumEnergy(data);
      });
    } catch (e) {
      debugPrint('TotalImpactPage daily fetch error: $e');
      setState(() => _errorDaily = true);
    } finally {
      setState(() => _loadingDaily = false);
    }
  }

  /// This month's total: 1st of current month → now.
  Future<void> _fetchMonthly() async {
    setState(() {
      _loadingMonthly = true;
      _errorMonthly = false;
      _emptyMonthly = false;
    });
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final data = await _getForRange(startOfMonth, now);

      if (data.isEmpty) {
        setState(() => _emptyMonthly = true);
        return;
      }
      setState(() {
        _monthlyCO2 = _sumCO2(data);
        _monthlyEnergy = _sumEnergy(data);
      });
    } catch (e) {
      debugPrint('TotalImpactPage monthly fetch error: $e');
      setState(() => _errorMonthly = true);
    } finally {
      setState(() => _loadingMonthly = false);
    }
  }

  /// This year's total: Jan 1 of current year → now.
  Future<void> _fetchYearly() async {
    setState(() {
      _loadingYearly = true;
      _errorYearly = false;
      _emptyYearly = false;
    });
    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final data = await _getForRange(startOfYear, now);

      if (data.isEmpty) {
        setState(() => _emptyYearly = true);
        return;
      }
      setState(() {
        _yearlyCO2 = _sumCO2(data);
        _yearlyEnergy = _sumEnergy(data);
      });
    } catch (e) {
      debugPrint('TotalImpactPage yearly fetch error: $e');
      setState(() => _errorYearly = true);
    } finally {
      setState(() => _loadingYearly = false);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

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
          _buildTab(
            co2: _dailyCO2,
            energy: _dailyEnergy,
            isLoading: _loadingDaily,
            hasError: _errorDaily,
            isEmpty: _emptyDaily,
            onRetry: _fetchDaily,
          ),
          _buildTab(
            co2: _monthlyCO2,
            energy: _monthlyEnergy,
            isLoading: _loadingMonthly,
            hasError: _errorMonthly,
            isEmpty: _emptyMonthly,
            onRetry: _fetchMonthly,
          ),
          _buildTab(
            co2: _yearlyCO2,
            energy: _yearlyEnergy,
            isLoading: _loadingYearly,
            hasError: _errorYearly,
            isEmpty: _emptyYearly,
            onRetry: _fetchYearly,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required double co2,
    required double energy,
    required bool isLoading,
    required bool hasError,
    required bool isEmpty,
    required VoidCallback onRetry,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasError) {
      return ErrorDisplay(
        message: 'Unable to load impact data for this period. '
            'Please check that Usage Access permission is still granted.',
        onRetry: onRetry,
      );
    }
    if (isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 56, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'No usage data available for this period.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: CarbonCircle(co2Value: co2, energyValue: energy),
    );
  }
}
