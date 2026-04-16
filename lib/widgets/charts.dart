import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/app_constants.dart';

/// Pie chart for a single dataset (no internal tabs).
/// Used by [StatsPage], which owns the tab structure and passes one period's
/// data at a time.
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
    final totalCo2 =
        widget.usageData.fold(0.0, (sum, d) => sum + (d['co2'] as double));
    final sections = widget.usageData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final co2 = data['co2'] as double;
      final pct = totalCo2 > 0 ? (co2 / totalCo2) * 100 : 0.0;
      final pkg = data['package'] as String;
      return PieChartSectionData(
        value: co2,
        title: '${pct.toStringAsFixed(1)}%',
        color: kAppColors[pkg] ?? Colors.grey,
        radius: index == _touchedIndex ? 95 : 80,
        titleStyle: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }).toList();

    final size = MediaQuery.of(context).size.width * 0.8;
    return SizedBox(
      width: size,
      height: size,
      child: PieChart(PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (_, response) {
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
    final totalCo2 =
        widget.usageData.fold(0.0, (sum, d) => sum + (d['co2'] as double));
    final size = MediaQuery.of(context).size.width * 0.8;
    return Container(
      padding: const EdgeInsets.all(16),
      width: size,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: widget.usageData.map((data) {
          final pkg = data['package'] as String;
          final co2 = data['co2'] as double;
          final pct = totalCo2 > 0 ? (co2 / totalCo2) * 100 : 0.0;
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
                '${appNameFromPackage(pkg)} (${pct.toStringAsFixed(1)}%)',
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
