import 'package:flutter/foundation.dart';
import 'app_constants.dart';
import 'database_service.dart';

// ---------------------------------------------------------------------------
// Recommendation model
// ---------------------------------------------------------------------------

class Recommendation {
  final String title;
  final String body;
  final String type; // "substitution" | "trend" | "budget" | "equivalence"
  final double? potentialSaving; // estimated CO₂ saving in grams
  final int priority;            // 1 = highest

  const Recommendation({
    required this.title,
    required this.body,
    required this.type,
    this.potentialSaving,
    required this.priority,
  });
}

// ---------------------------------------------------------------------------
// Equivalence conversion factors (well-known constants, not app config)
// ---------------------------------------------------------------------------

const double _co2PerKmDriving = 120.0;  // grams — average passenger car
const double _co2PerPhoneCharge = 15.0; // grams — full smartphone charge
const double _co2PerLedHour = 5.0;      // grams — 1 hour of LED bulb

// ---------------------------------------------------------------------------
// RecommendationEngine
// ---------------------------------------------------------------------------

class RecommendationEngine {
  final DatabaseService db;

  const RecommendationEngine({required this.db});

  /// Generates up to 3 personalised recommendations sorted by priority.
  /// Returns an empty list when fewer than 3 days of data are stored.
  Future<List<Recommendation>> generateRecommendations() async {
    final storedDays = await db.countStoredDays();
    if (storedDays < 3) return [];

    final candidates = <Recommendation>[];

    final sub = await _substitutionRecommendation();
    if (sub != null) candidates.add(sub);

    final trend = await _trendRecommendation();
    if (trend != null) candidates.add(trend);

    final budget = await _budgetNudge();
    if (budget != null) candidates.add(budget);

    final equiv = await _equivalenceRecommendation();
    if (equiv != null) candidates.add(equiv);

    candidates.sort((a, b) => a.priority.compareTo(b.priority));
    final result = candidates.take(3).toList();

    if (result.isNotEmpty) {
      final today = dateString(DateTime.now());
      for (final rec in result) {
        await db.insertRecommendation(
          date: today,
          recommendationText: rec.body,
          recommendationType: rec.type,
          potentialCo2Saving: rec.potentialSaving,
        );
      }
    }

    return result;
  }

  // -------------------------------------------------------------------------
  // Strategy 1 — App Substitution
  // Identifies the highest-CO₂ app over the last 7 days and estimates the
  // saving if 25 % of that time were shifted to the lowest-emission app.
  // -------------------------------------------------------------------------

  Future<Recommendation?> _substitutionRecommendation() async {
    try {
      final records = await db.getLastNDaysUsage(7);
      if (records.isEmpty) return null;

      final Map<String, double> minutesByPkg = {};
      final Map<String, double> co2ByPkg = {};
      for (final r in records) {
        minutesByPkg[r.packageName] = (minutesByPkg[r.packageName] ?? 0) + r.minutes;
        co2ByPkg[r.packageName] = (co2ByPkg[r.packageName] ?? 0) + r.co2Grams;
      }
      if (co2ByPkg.isEmpty) return null;

      final highEntry =
          co2ByPkg.entries.reduce((a, b) => a.value > b.value ? a : b);
      final highPkg = highEntry.key;
      if (highPkg == kLowestCo2Package) return null;

      final highMinutes = minutesByPkg[highPkg] ?? 0;
      final highCo2Total = co2ByPkg[highPkg] ?? 0;
      final highRate = kCo2PerMinute[highPkg] ?? 0;
      final lowRate = kCo2PerMinute[kLowestCo2Package]!;

      final savingsPerMin = highRate - lowRate;
      final suggestedShift = highMinutes * 0.25;
      final potentialSaving = suggestedShift * savingsPerMin;
      if (potentialSaving <= 0) return null;

      final highName = appNameFromPackage(highPkg);
      final lowName = appNameFromPackage(kLowestCo2Package);
      final shiftMins = suggestedShift.round();
      final phoneCharges = (potentialSaving / _co2PerPhoneCharge).toStringAsFixed(1);

      return Recommendation(
        title: 'Swap some $highName time for $lowName',
        body: 'You spent ${highMinutes.round()} min on $highName this week '
            '(${highCo2Total.toStringAsFixed(1)}g CO₂). Shifting $shiftMins min '
            'to $lowName could save ${potentialSaving.toStringAsFixed(1)}g CO₂ — '
            'like charging your phone $phoneCharges times.',
        type: 'substitution',
        potentialSaving: potentialSaving,
        priority: 1,
      );
    } catch (e) {
      debugPrint('RecommendationEngine substitution error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Strategy 2 — Trend Detection
  // Compares this week's total CO₂ to last week's. Alerts on >15 % increase;
  // encourages on any decrease.
  // -------------------------------------------------------------------------

  Future<Recommendation?> _trendRecommendation() async {
    try {
      final now = DateTime.now();
      final thisWeek = await db.getLastNDaysUsage(7);
      final lastWeek = await db.getUsageRange(
        dateString(now.subtract(const Duration(days: 14))),
        dateString(now.subtract(const Duration(days: 7))),
      );

      if (thisWeek.isEmpty || lastWeek.isEmpty) return null;

      final thisWeekCo2 = thisWeek.fold(0.0, (s, r) => s + r.co2Grams);
      final lastWeekCo2 = lastWeek.fold(0.0, (s, r) => s + r.co2Grams);
      if (lastWeekCo2 == 0) return null;

      final changePct = ((thisWeekCo2 - lastWeekCo2) / lastWeekCo2) * 100;

      if (changePct > 15) {
        final thisWeekMins = _aggregateMinutes(thisWeek);
        final lastWeekMins = _aggregateMinutes(lastWeek);
        String? biggestApp;
        double biggestDelta = 0;
        for (final pkg in thisWeekMins.keys) {
          final delta = (thisWeekMins[pkg] ?? 0) - (lastWeekMins[pkg] ?? 0);
          if (delta > biggestDelta) {
            biggestDelta = delta;
            biggestApp = pkg;
          }
        }
        final appDetail = biggestApp != null && biggestDelta > 0
            ? ' Your ${appNameFromPackage(biggestApp)} usage grew the most '
                '(+${biggestDelta.round()} min).'
            : '';

        return Recommendation(
          title: 'Your footprint is trending up',
          body: 'Your digital carbon footprint increased by '
              '${changePct.toStringAsFixed(0)}% compared to last week.$appDetail '
              'Consider setting a daily screen-time goal to reverse this.',
          type: 'trend_increase',
          priority: 2,
        );
      } else if (changePct < 0) {
        return Recommendation(
          title: 'Great progress this week!',
          body: 'Your carbon footprint dropped by '
              '${changePct.abs().toStringAsFixed(0)}% compared to last week. '
              'Keep it up — small changes add up over time!',
          type: 'trend_decrease',
          priority: 2,
        );
      }

      return null; // Within ±15 % — no alert needed
    } catch (e) {
      debugPrint('RecommendationEngine trend error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Strategy 3 — Daily Budget Nudge
  // Alerts when today's CO₂ already exceeds the historical daily average by
  // more than 20 %, provided it is before 8 PM.
  // -------------------------------------------------------------------------

  Future<Recommendation?> _budgetNudge() async {
    try {
      if (DateTime.now().hour >= 20) return null;

      final allRecords = await db.getAllUsageData();
      if (allRecords.isEmpty) return null;

      final distinctDates = allRecords.map((r) => r.date).toSet();
      final totalCo2 = allRecords.fold(0.0, (s, r) => s + r.co2Grams);
      final avgDailyCo2 = totalCo2 / distinctDates.length;
      if (avgDailyCo2 == 0) return null;

      final today = dateString(DateTime.now());
      final todayRecords = await db.getDailyUsage(today);
      final todayCo2 = todayRecords.fold(0.0, (s, r) => s + r.co2Grams);

      if (todayCo2 <= avgDailyCo2 * 1.2) return null;

      final pct = ((todayCo2 / avgDailyCo2) * 100).round();
      final hour = DateTime.now().hour;

      return Recommendation(
        title: 'Above your daily average',
        body: "You've already reached $pct% of your typical daily carbon budget "
            'and it\'s only ${_formatHour(hour)}. Consider reducing screen time '
            'for the rest of the day — your future self will thank you!',
        type: 'budget',
        priority: 3,
      );
    } catch (e) {
      debugPrint('RecommendationEngine budget error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Strategy 4 — Equivalence Comparisons
  // Converts last 7 days' total CO₂ into tangible real-world equivalents.
  // -------------------------------------------------------------------------

  Future<Recommendation?> _equivalenceRecommendation() async {
    try {
      final records = await db.getLastNDaysUsage(7);
      if (records.isEmpty) return null;

      final totalCo2 = records.fold(0.0, (s, r) => s + r.co2Grams);
      if (totalCo2 == 0) return null;

      final kmDriving = (totalCo2 / _co2PerKmDriving).toStringAsFixed(2);
      final phoneCharges = (totalCo2 / _co2PerPhoneCharge).toStringAsFixed(1);
      final ledHours = (totalCo2 / _co2PerLedHour).toStringAsFixed(1);

      return Recommendation(
        title: 'Your week in perspective',
        body: 'Your weekly social media footprint (${totalCo2.toStringAsFixed(1)}g CO₂) '
            'equals driving $kmDriving km by car, charging your phone $phoneCharges times, '
            'or running an LED bulb for $ledHours hours.',
        type: 'equivalence',
        priority: 4,
      );
    } catch (e) {
      debugPrint('RecommendationEngine equivalence error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Map<String, double> _aggregateMinutes(List<AppUsage> records) {
    final Map<String, double> result = {};
    for (final r in records) {
      result[r.packageName] = (result[r.packageName] ?? 0) + r.minutes;
    }
    return result;
  }

  String _formatHour(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:00 $suffix';
  }
}
