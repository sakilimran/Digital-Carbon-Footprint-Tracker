import 'package:flutter/foundation.dart';
import 'database_service.dart';

// ---------------------------------------------------------------------------
// Recommendation model
// ---------------------------------------------------------------------------

class Recommendation {
  final String title;
  final String body;
  final String type; // "substitution" | "trend" | "budget" | "equivalence"
  final double? potentialSaving; // estimated CO₂ saving in grams
  final int priority; // 1 = highest

  const Recommendation({
    required this.title,
    required this.body,
    required this.type,
    this.potentialSaving,
    required this.priority,
  });
}

// ---------------------------------------------------------------------------
// Internal constants — mirror of UsageService rates
// ---------------------------------------------------------------------------

const Map<String, double> _co2RatesPerMinute = {
  'com.google.android.youtube': 0.46,
  'tv.twitch.android.app': 0.55,
  'com.twitter.android': 0.60,
  'com.linkedin.android': 0.71,
  'com.facebook.katana': 0.79,
  'com.snapchat.android': 0.87,
  'com.instagram.android': 1.05,
  'com.pinterest': 1.30,
  'com.reddit.frontpage': 2.48,
  'com.zhiliaoapp.musically': 2.63,
};

// Lowest CO₂ rate in the tracked set (YouTube)
const String _lowestCo2Package = 'com.google.android.youtube';
const double _lowestCo2Rate = 0.46;

// Real-world equivalence factors
const double _co2PerKmDriving = 120.0;   // grams per km (average car)
const double _co2PerPhoneCharge = 15.0;  // grams per full smartphone charge
const double _co2PerLedHour = 5.0;       // grams per hour of LED light

// ---------------------------------------------------------------------------
// RecommendationEngine
// ---------------------------------------------------------------------------

class RecommendationEngine {
  final DatabaseService db;

  const RecommendationEngine({required this.db});

  /// Generates up to 3 personalised recommendations.
  /// Returns an empty list when fewer than 3 days of data are stored.
  Future<List<Recommendation>> generateRecommendations() async {
    final storedDays = await db.countStoredDays();
    if (storedDays < 3) return [];

    final candidates = <Recommendation>[];

    final substitution = await _substitutionRecommendation();
    if (substitution != null) candidates.add(substitution);

    final trend = await _trendRecommendation();
    if (trend != null) candidates.add(trend);

    final budget = await _budgetNudge();
    if (budget != null) candidates.add(budget);

    final equiv = await _equivalenceRecommendation();
    if (equiv != null) candidates.add(equiv);

    // Sort by priority (1 = highest) and take at most 3
    candidates.sort((a, b) => a.priority.compareTo(b.priority));
    final result = candidates.take(3).toList();

    // Persist to recommendations_log
    if (result.isNotEmpty) {
      final today = _dateStr(DateTime.now());
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
  // -------------------------------------------------------------------------

  Future<Recommendation?> _substitutionRecommendation() async {
    try {
      final records = await db.getLastNDaysUsage(7);
      if (records.isEmpty) return null;

      // Aggregate minutes and CO₂ by package over the last 7 days
      final Map<String, double> minutesByPkg = {};
      final Map<String, double> co2ByPkg = {};
      for (final r in records) {
        minutesByPkg[r.packageName] =
            (minutesByPkg[r.packageName] ?? 0) + r.minutes;
        co2ByPkg[r.packageName] =
            (co2ByPkg[r.packageName] ?? 0) + r.co2Grams;
      }

      if (co2ByPkg.isEmpty) return null;

      // Find the highest-CO₂ app
      final highEntry =
          co2ByPkg.entries.reduce((a, b) => a.value > b.value ? a : b);
      final highPackage = highEntry.key;

      // No point suggesting switching YouTube to YouTube
      if (highPackage == _lowestCo2Package) return null;

      final highMinutes = minutesByPkg[highPackage] ?? 0;
      final highCo2Total = co2ByPkg[highPackage] ?? 0;
      final highRate = _co2RatesPerMinute[highPackage] ?? 0;

      final savingsPerMin = highRate - _lowestCo2Rate;
      final suggestedShift = highMinutes * 0.25;
      final potentialSaving = suggestedShift * savingsPerMin;

      if (potentialSaving <= 0) return null;

      final highName = appNameFromPackage(highPackage);
      final lowName = appNameFromPackage(_lowestCo2Package);
      final shiftMins = suggestedShift.round();
      final phoneCharges = (potentialSaving / _co2PerPhoneCharge).toStringAsFixed(1);

      return Recommendation(
        title: 'Swap some $highName time for $lowName',
        body: 'You spent ${highMinutes.round()} minutes on $highName this week '
            '(${highCo2Total.toStringAsFixed(1)}g CO₂). Shifting $shiftMins minutes '
            'to $lowName could save ${potentialSaving.toStringAsFixed(1)}g CO₂ — '
            'equivalent to charging your phone $phoneCharges times.',
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
  // -------------------------------------------------------------------------

  Future<Recommendation?> _trendRecommendation() async {
    try {
      final now = DateTime.now();

      final thisWeek = await db.getLastNDaysUsage(7);
      final lastWeekStart = now.subtract(const Duration(days: 14));
      final lastWeekEnd = now.subtract(const Duration(days: 7));
      final lastWeek = await db.getUsageRange(
        _dateStr(lastWeekStart),
        _dateStr(lastWeekEnd),
      );

      if (thisWeek.isEmpty || lastWeek.isEmpty) return null;

      final thisWeekCo2 = thisWeek.fold(0.0, (s, r) => s + r.co2Grams);
      final lastWeekCo2 = lastWeek.fold(0.0, (s, r) => s + r.co2Grams);

      if (lastWeekCo2 == 0) return null;

      final changePct = ((thisWeekCo2 - lastWeekCo2) / lastWeekCo2) * 100;

      if (changePct > 15) {
        // Find the app whose usage grew the most
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
                '(+${biggestDelta.round()} minutes).'
            : '';

        return Recommendation(
          title: 'Your footprint is trending up',
          body: 'Your digital carbon footprint increased by '
              '${changePct.toStringAsFixed(0)}% compared to last week.$appDetail '
              'Consider setting a daily screen time goal to turn this around.',
          type: 'trend',
          priority: 2,
        );
      } else if (changePct < 0) {
        return Recommendation(
          title: 'Great progress this week!',
          body: 'Your carbon footprint dropped by '
              '${changePct.abs().toStringAsFixed(0)}% compared to last week. '
              'Keep it up — small changes add up over time!',
          type: 'trend',
          priority: 2,
        );
      }

      return null; // Change within ±15% — no alert needed
    } catch (e) {
      debugPrint('RecommendationEngine trend error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Strategy 3 — Daily Budget Nudge
  // -------------------------------------------------------------------------

  Future<Recommendation?> _budgetNudge() async {
    try {
      final currentHour = DateTime.now().hour;
      if (currentHour >= 20) return null; // Too late in the day to nudge

      final allRecords = await db.getAllUsageData();
      if (allRecords.isEmpty) return null;

      final distinctDates = allRecords.map((r) => r.date).toSet();
      final totalCo2 = allRecords.fold(0.0, (s, r) => s + r.co2Grams);
      final avgDailyCo2 = totalCo2 / distinctDates.length;

      if (avgDailyCo2 == 0) return null;

      final today = _dateStr(DateTime.now());
      final todayRecords = await db.getDailyUsage(today);
      final todayCo2 = todayRecords.fold(0.0, (s, r) => s + r.co2Grams);

      if (todayCo2 <= avgDailyCo2 * 1.2) return null;

      final pct = ((todayCo2 / avgDailyCo2) * 100).round();

      return Recommendation(
        title: 'Above your daily average',
        body: "You've already reached $pct% of your typical daily carbon budget "
            'and it\'s only ${_formatHour(currentHour)}. '
            'Consider reducing screen time for the rest of the day — '
            'your future self will thank you!',
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
            'is equivalent to driving ${kmDriving}km by car, '
            'charging your phone $phoneCharges times, '
            'or running an LED light for $ledHours hours.',
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

  String _dateStr(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  String _formatHour(int hour) {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:00 $suffix';
  }
}
