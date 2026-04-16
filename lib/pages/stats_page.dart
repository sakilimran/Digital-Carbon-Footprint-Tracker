import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../services/database_service.dart';
import '../widgets/charts.dart';
import '../widgets/app_drawer.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final UsageService _usageService = UsageService();
  final DatabaseService _db = DatabaseService();

  final Map<String, List<Map<String, dynamic>>> _usageDataByPeriod = {
    'weekly': [],
    'monthly': [],
    'yearly': [],
  };

  bool _loadingWeekly = true;
  bool _loadingMonthly = true;
  bool _loadingYearly = true;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    await _fetchWeeklyUsage();
    await _fetchMonthlyUsage();
    await _fetchYearlyUsage();
  }

  /// Returns aggregated usage for the given range.
  /// Tries SQLite first; falls back to the native API if no stored data exists.
  Future<List<Map<String, dynamic>>> _getUsageForRange(
      DateTime start, DateTime end) async {
    final startStr = _dateString(start);
    final endStr = _dateString(end);

    final stored = await _db.getAggregatedUsageForRange(startStr, endStr);
    if (stored.isNotEmpty) return stored;

    // Fall back to native API
    return _usageService.getRangeUsage(start: start, end: end);
  }

  Future<void> _fetchWeeklyUsage() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final usageList = await _getUsageForRange(start, now);
      setState(() {
        _usageDataByPeriod['weekly'] = usageList;
      });
    } catch (e) {
      debugPrint('Error fetching weekly usage: $e');
    } finally {
      setState(() {
        _loadingWeekly = false;
      });
    }
  }

  Future<void> _fetchMonthlyUsage() async {
    try {
      final now = DateTime.now();
      final start = _subtractOneMonth(now);
      final usageList = await _getUsageForRange(start, now);
      setState(() {
        _usageDataByPeriod['monthly'] = usageList;
      });
    } catch (e) {
      debugPrint('Error fetching monthly usage: $e');
    } finally {
      setState(() {
        _loadingMonthly = false;
      });
    }
  }

  Future<void> _fetchYearlyUsage() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year - 1, now.month, now.day);
      final usageList = await _getUsageForRange(start, now);
      setState(() {
        _usageDataByPeriod['yearly'] = usageList;
      });
    } catch (e) {
      debugPrint('Error fetching yearly usage: $e');
    } finally {
      setState(() {
        _loadingYearly = false;
      });
    }
  }

  /// Safely subtracts one month, clamping to the last valid day of that month.
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Statistics'),
      ),
      drawer: const AppDrawer(),
      body: _loadingWeekly || _loadingMonthly || _loadingYearly
          ? const Center(child: CircularProgressIndicator())
          : SocialMediaPieChart(
              usageDataByPeriod: _usageDataByPeriod,
            ),
    );
  }
}
