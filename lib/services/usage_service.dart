import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'app_constants.dart';

class UsageService {
  static const _channel = MethodChannel('social_media_carbon_footprint/usage');

  /// Fetches today's app usage from the native Android layer.
  /// Returns a list of maps: {package, minutes, co2, energy}.
  /// CO₂ and energy values come pre-calculated from MainActivity; the
  /// null-coalescing fallback here handles any edge case where the native
  /// side omits them.
  Future<List<Map<String, dynamic>>> getTodayUsage() async {
    try {
      final String result = await _channel.invokeMethod('getDailyUsage');
      final List<Map<String, dynamic>> usageList =
          List<Map<String, dynamic>>.from(json.decode(result));

      for (final usage in usageList) {
        final pkg = usage['package'] as String;
        final mins = usage['minutes'] as double;
        usage['co2'] ??= mins * (kCo2PerMinute[pkg] ?? 0.0);
        usage['energy'] ??= mins * (kEnergyPerMinute[pkg] ?? 0.0);
      }

      return usageList;
    } on PlatformException catch (e) {
      debugPrint('UsageService.getTodayUsage error: $e');
      return [];
    }
  }

  /// Fetches usage data for a custom date range from the native Android layer.
  /// Returns a list of maps: {package, minutes, co2, energy}.
  Future<List<Map<String, dynamic>>> getRangeUsage({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final String result = await _channel.invokeMethod('getRangeUsage', {
        'startTime': start.millisecondsSinceEpoch,
        'endTime': end.millisecondsSinceEpoch,
      });
      final List<Map<String, dynamic>> usageList =
          List<Map<String, dynamic>>.from(json.decode(result));

      for (final usage in usageList) {
        final pkg = usage['package'] as String;
        final mins = usage['minutes'] as double;
        usage['co2'] ??= mins * (kCo2PerMinute[pkg] ?? 0.0);
        usage['energy'] ??= mins * (kEnergyPerMinute[pkg] ?? 0.0);
      }

      return usageList;
    } on PlatformException catch (e) {
      debugPrint('UsageService.getRangeUsage error: $e');
      return [];
    }
  }
}
