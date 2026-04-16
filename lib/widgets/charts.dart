import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Shared constants (used by both chart widgets)
// ---------------------------------------------------------------------------

const Map<String, Color> kAppColors = {
  'com.google.android.youtube': Color(0xFFADD8E6), // Light Blue
  'tv.twitch.android.app': Color(0xFFFFB6C1),       // Light Pink
  'com.twitter.android': Color(0xFF87CEFA),          // Sky Blue
  'com.linkedin.android': Color(0xFFB0E0E6),         // Powder Blue
  'com.facebook.katana': Color(0xFFFFA07A),          // Light Salmon
  'com.snapchat.android': Color(0xFFFFFF99),         // Light Yellow
  'com.instagram.android': Color(0xFFFFDAB9),        // Peach Puff
  'com.pinterest': Color(0xFFD8BFD8),                // Thistle
  'com.reddit.frontpage': Color(0xFFFF9999),         // Light Coral
  'com.zhiliaoapp.musically': Color(0xFF98FB98),     // Pale Green (TikTok)
};

const Map<String, String> kPackageToName = {
  'com.google.android.youtube': 'YouTube',
  'tv.twitch.android.app': 'Twitch',
  'com.twitter.android': 'Twitter',
  'com.linkedin.android': 'LinkedIn',
  'com.facebook.katana': 'Facebook',
  'com.snapchat.android': 'Snapchat',
  'com.instagram.android': 'Instagram',
  'com.pinterest': 'Pinterest',
  'com.reddit.frontpage': 'Reddit',
  'com.zhiliaoapp.musically': 'TikTok',
};

String getAppName(String packageName) =>
    kPackageToName[packageName] ?? packageName;

// ---------------------------------------------------------------------------
// SocialMediaPieChart — multi-period (Weekly / Monthly / Yearly tabs)
// Used by the old stats_page flow; kept for backwards compatibility.
// ---------------------------------------------------------------------------

class SocialMediaPieChart extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> usageDataByPeriod;

  const SocialMediaPieChart({Key? key, required this.usageDataByPeriod})
      : super(key: key);

  @override
  State<SocialMediaPieChart> createState() => _SocialMediaPieChartState();
}

class _SocialMediaPieChartState extends State<SocialMediaPieChart>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Yearly'),
          ],
          labelColor: Colors.black,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChartView(widget.usageDataByPeriod['weekly'] ?? []),
              _buildChartView(widget.usageDataByPeriod['monthly'] ?? []),
              _buildChartView(widget.usageDataByPeriod['yearly'] ?? []),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartView(List<Map<String, dynamic>> usageData) {
    if (usageData.isEmpty) {
      return const Center(child: Text('No data available.'));
    }
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPieChart(usageData),
          const SizedBox(height: 16),
          _buildLegend(usageData),
        ],
      ),
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> usageData) {
    final totalCO2 =
        usageData.fold(0.0, (sum, d) => sum + (d['co2'] as double));
    final sections = usageData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final co2 = data['co2'] as double;
      final pct = totalCO2 > 0 ? (co2 / totalCO2) * 100 : 0;
      final pkg = data['package'] as String;
      return PieChartSectionData(
        value: co2,
        title: '${pct.toStringAsFixed(1)}%',
        color: kAppColors[pkg] ?? Colors.grey,
        radius: index == _touchedIndex ? 95 : 80,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }).toList();

    final w = MediaQuery.of(context).size.width * 0.8;
    return SizedBox(
      width: w,
      height: w,
      child: PieChart(PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
            });
          },
        ),
      )),
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>> usageData) {
    final totalCO2 =
        usageData.fold(0.0, (sum, d) => sum + (d['co2'] as double));
    final w = MediaQuery.of(context).size.width * 0.8;
    return Container(
      padding: const EdgeInsets.all(16),
      width: w,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: usageData.map((data) {
          final pkg = data['package'] as String;
          final co2 = data['co2'] as double;
          final pct = totalCO2 > 0 ? (co2 / totalCO2) * 100 : 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kAppColors[pkg] ?? Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${getAppName(pkg)} (${pct.toStringAsFixed(1)}%)',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SinglePeriodChart — single dataset, no internal tabs.
// Used by the refactored stats_page which owns its own tab structure.
// ---------------------------------------------------------------------------

class SinglePeriodChart extends StatefulWidget {
  final List<Map<String, dynamic>> usageData;

  const SinglePeriodChart({Key? key, required this.usageData}) : super(key: key);

  @override
  State<SinglePeriodChart> createState() => _SinglePeriodChartState();
}

class _SinglePeriodChartState extends State<SinglePeriodChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPieChart(),
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final totalCO2 = widget.usageData
        .fold(0.0, (sum, d) => sum + (d['co2'] as double));
    final sections = widget.usageData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final co2 = data['co2'] as double;
      final pct = totalCO2 > 0 ? (co2 / totalCO2) * 100 : 0;
      final pkg = data['package'] as String;
      return PieChartSectionData(
        value: co2,
        title: '${pct.toStringAsFixed(1)}%',
        color: kAppColors[pkg] ?? Colors.grey,
        radius: index == _touchedIndex ? 95 : 80,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }).toList();

    final w = MediaQuery.of(context).size.width * 0.8;
    return SizedBox(
      width: w,
      height: w,
      child: PieChart(PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {
            setState(() {
              _touchedIndex =
                  response?.touchedSection?.touchedSectionIndex ?? -1;
            });
          },
        ),
      )),
    );
  }

  Widget _buildLegend() {
    final totalCO2 = widget.usageData
        .fold(0.0, (sum, d) => sum + (d['co2'] as double));
    final w = MediaQuery.of(context).size.width * 0.8;
    return Container(
      padding: const EdgeInsets.all(16),
      width: w,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: widget.usageData.map((data) {
          final pkg = data['package'] as String;
          final co2 = data['co2'] as double;
          final pct = totalCO2 > 0 ? (co2 / totalCO2) * 100 : 0;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kAppColors[pkg] ?? Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${getAppName(pkg)} (${pct.toStringAsFixed(1)}%)',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
