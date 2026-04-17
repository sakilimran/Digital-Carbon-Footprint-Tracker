import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'app_constants.dart';

class UsageService {
  static const _channel = MethodChannel(kChannelName);

  // -------------------------------------------------------------------------
  // Permission helpers
  // -------------------------------------------------------------------------

  /// Returns true if Android Usage Access permission has been granted.
  Future<bool> hasUsagePermission() async {
    try {
      return await _channel.invokeMethod('hasUsagePermission') as bool;
    } catch (e) {
      debugPrint('UsageService.hasUsagePermission error: $e');
      return false;
    }
  }

  /// Opens the Android Usage Access settings screen.
  Future<void> openUsageSettings() async {
    try {
      await _channel.invokeMethod('openUsageSettings');
    } catch (e) {
      debugPrint('UsageService.openUsageSettings error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Usage data
  // -------------------------------------------------------------------------

  /// Fetches today's app usage from the native Android layer.
  /// Returns a list of maps: {package, minutes, co2, energy}.
  /// CO₂ and energy values come pre-calculated from MainActivity; the
  /// null-coalescing fallback handles any edge case where the native side
  /// omits them.
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
    } catch (e) {
      // Catches PlatformException (native error), FormatException (malformed JSON
      // from locale-sensitive String.format on older builds), and cast errors.
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
    } catch (e) {
      debugPrint('UsageService.getRangeUsage error: $e');
      return [];
    }
  }
}
