import 'package:flutter/material.dart';
import '../services/usage_service.dart';
import '../widgets/charts.dart';
import '../widgets/app_drawer.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({Key? key}) : super(key: key);

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final UsageService _usageService = UsageService();

  // Data placeholders
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _yearlyData = [];

  bool _loadingWeekly = true;
  bool _loadingMonthly = true;
  bool _loadingYearly = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  /// Fetch all time ranges in sequence
  Future<void> _fetchAllData() async {
    await _fetchWeeklyUsage();
    await _fetchMonthlyUsage();
    await _fetchYearlyUsage();
  }

  Future<void> _fetchWeeklyUsage() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      final usageList = await _usageService.getRangeUsage(start: start, end: now);
      setState(() {
        _weeklyData = usageList;
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
      final start = DateTime(now.year, now.month - 1, now.day);
      final usageList = await _usageService.getRangeUsage(start: start, end: now);
      setState(() {
        _monthlyData = usageList;
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
      final usageList = await _usageService.getRangeUsage(start: start, end: now);
      setState(() {
        _yearlyData = usageList;
      });
    } catch (e) {
      debugPrint('Error fetching yearly usage: $e');
    } finally {
      setState(() {
        _loadingYearly = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Statistics'),
        bottom: TabBar(
          controller: _tabController,
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
          _buildTabContent(_weeklyData, _loadingWeekly),
          _buildTabContent(_monthlyData, _loadingMonthly),
          _buildTabContent(_yearlyData, _loadingYearly),
        ],
      ),
    );
  }

  /// Helper to build each tab's content based on data + loading flags
  Widget _buildTabContent(List<Map<String, dynamic>> usageData, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (usageData.isEmpty) {
      // If data is fetched but array is empty, show a "No data" message
      return const Center(child: Text('No data available.'));
    }
    // Otherwise, show the charts
    return SingleChildScrollView(
      child: Column(
        children: [
          // Pie Chart
          SizedBox(
            height: 300,
            child: SocialMediaPieChart(usageData: usageData),
          ),
          const SizedBox(height: 20),
          // Line Chart
          SizedBox(
            height: 300,
            child: SocialMediaLineChart(usageData: usageData),
          ),
        ],
      ),
    );
  }
}
