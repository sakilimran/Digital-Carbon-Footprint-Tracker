import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../widgets/charts.dart';
import '../widgets/error_display.dart';
import '../widgets/app_drawer.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  final UsageService _usageService = UsageService();
  final DatabaseService _db = DatabaseService();

  late TabController _tabController;

  // Data
  final Map<String, List<Map<String, dynamic>>> _usageDataByPeriod = {
    'weekly': [],
    'monthly': [],
    'yearly': [],
  };

  // Loading flags
  bool _loadingWeekly = true;
  bool _loadingMonthly = true;
  bool _loadingYearly = true;

  // Error flags
  bool _errorWeekly = false;
  bool _errorMonthly = false;
  bool _errorYearly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchWeeklyUsage(),
      _fetchMonthlyUsage(),
      _fetchYearlyUsage(),
    ]);
  }

  Future<List<Map<String, dynamic>>> _getUsageForRange(
      DateTime start, DateTime end) async {
    final stored = await _db.getAggregatedUsageForRange(
        _dateString(start), _dateString(end));
    if (stored.isNotEmpty) return stored;
    return _usageService.getRangeUsage(start: start, end: end);
  }

  Future<void> _fetchWeeklyUsage() async {
    setState(() {
      _loadingWeekly = true;
      _errorWeekly = false;
    });
    try {
      final now = DateTime.now();
      final data = await _getUsageForRange(
          now.subtract(const Duration(days: 7)), now);
      setState(() => _usageDataByPeriod['weekly'] = data);
    } catch (e) {
      debugPrint('Error fetching weekly usage: $e');
      setState(() => _errorWeekly = true);
    } finally {
      setState(() => _loadingWeekly = false);
    }
  }

  Future<void> _fetchMonthlyUsage() async {
    setState(() {
      _loadingMonthly = true;
      _errorMonthly = false;
    });
    try {
      final now = DateTime.now();
      final data = await _getUsageForRange(_subtractOneMonth(now), now);
      setState(() => _usageDataByPeriod['monthly'] = data);
    } catch (e) {
      debugPrint('Error fetching monthly usage: $e');
      setState(() => _errorMonthly = true);
    } finally {
      setState(() => _loadingMonthly = false);
    }
  }

  Future<void> _fetchYearlyUsage() async {
    setState(() {
      _loadingYearly = true;
      _errorYearly = false;
    });
    try {
      final now = DateTime.now();
      final data = await _getUsageForRange(
          DateTime(now.year - 1, now.month, now.day), now);
      setState(() => _usageDataByPeriod['yearly'] = data);
    } catch (e) {
      debugPrint('Error fetching yearly usage: $e');
      setState(() => _errorYearly = true);
    } finally {
      setState(() => _loadingYearly = false);
    }
  }

  // Task 6a — safe month subtraction
  DateTime _subtractOneMonth(DateTime date) {
    final year = date.month == 1 ? date.year - 1 : date.year;
    final month = date.month == 1 ? 12 : date.month - 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  String _dateString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Statistics'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          tabs: const [
            Tab(text: 'Weekly'),
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
            isLoading: _loadingWeekly,
            hasError: _errorWeekly,
            data: _usageDataByPeriod['weekly']!,
            onRetry: _fetchWeeklyUsage,
          ),
          _buildTab(
            isLoading: _loadingMonthly,
            hasError: _errorMonthly,
            data: _usageDataByPeriod['monthly']!,
            onRetry: _fetchMonthlyUsage,
          ),
          _buildTab(
            isLoading: _loadingYearly,
            hasError: _errorYearly,
            data: _usageDataByPeriod['yearly']!,
            onRetry: _fetchYearlyUsage,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required bool isLoading,
    required bool hasError,
    required List<Map<String, dynamic>> data,
    required VoidCallback onRetry,
  }) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    if (hasError) {
      return ErrorDisplay(
        message: 'Unable to load usage data for this period. '
            'Please check that Usage Access permission is still granted.',
        onRetry: onRetry,
      );
    }

    if (data.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart, size: 56, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'No social media usage detected for this period.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return SinglePeriodChart(usageData: data);
  }
}
