import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../services/app_constants.dart';
import '../widgets/charts.dart';
import '../widgets/error_display.dart';
import '../widgets/app_drawer.dart';

/// Shows a pie chart of CO₂ distribution across tracked apps for three periods:
///   Weekly  — last 7 days
///   Monthly — last calendar month (today minus one month)
///   Yearly  — last 12 months (today minus one year)
///
/// Each tab is independent: its loading, error, and empty states are managed
/// separately so a failure in one period does not affect the others.
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

  final Map<String, List<Map<String, dynamic>>> _data = {
    'weekly': [],
    'monthly': [],
    'yearly': [],
  };

  bool _loadingWeekly = true;
  bool _loadingMonthly = true;
  bool _loadingYearly = true;

  bool _errorWeekly = false;
  bool _errorMonthly = false;
  bool _errorYearly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.wait([
      _fetchWeekly(),
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

  Future<void> _fetchWeekly() async {
    setState(() {
      _loadingWeekly = true;
      _errorWeekly = false;
    });
    try {
      final now = DateTime.now();
      final data = await _getForRange(now.subtract(const Duration(days: 7)), now);
      setState(() => _data['weekly'] = data);
    } catch (e) {
      debugPrint('StatsPage weekly fetch error: $e');
      setState(() => _errorWeekly = true);
    } finally {
      setState(() => _loadingWeekly = false);
    }
  }

  Future<void> _fetchMonthly() async {
    setState(() {
      _loadingMonthly = true;
      _errorMonthly = false;
    });
    try {
      final now = DateTime.now();
      final data = await _getForRange(subtractOneMonth(now), now);
      setState(() => _data['monthly'] = data);
    } catch (e) {
      debugPrint('StatsPage monthly fetch error: $e');
      setState(() => _errorMonthly = true);
    } finally {
      setState(() => _loadingMonthly = false);
    }
  }

  Future<void> _fetchYearly() async {
    setState(() {
      _loadingYearly = true;
      _errorYearly = false;
    });
    try {
      final now = DateTime.now();
      final data = await _getForRange(
          DateTime(now.year - 1, now.month, now.day), now);
      setState(() => _data['yearly'] = data);
    } catch (e) {
      debugPrint('StatsPage yearly fetch error: $e');
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
            data: _data['weekly']!,
            onRetry: _fetchWeekly,
          ),
          _buildTab(
            isLoading: _loadingMonthly,
            hasError: _errorMonthly,
            data: _data['monthly']!,
            onRetry: _fetchMonthly,
          ),
          _buildTab(
            isLoading: _loadingYearly,
            hasError: _errorYearly,
            data: _data['yearly']!,
            onRetry: _fetchYearly,
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
