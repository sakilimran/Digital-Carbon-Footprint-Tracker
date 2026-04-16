import 'package:flutter/material.dart';

// Source: Greenspector 2021 Social Media study
// https://greenspector.com/en/social-media-2021/

/// CO₂ emissions in grams per minute of foreground app use.
const Map<String, double> kCo2PerMinute = {
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

/// Battery consumption in mAh per minute of foreground app use.
const Map<String, double> kEnergyPerMinute = {
  'com.google.android.youtube': 8.58,
  'tv.twitch.android.app': 9.05,
  'com.twitter.android': 10.28,
  'com.linkedin.android': 8.92,
  'com.facebook.katana': 12.36,
  'com.snapchat.android': 11.48,
  'com.instagram.android': 8.90,
  'com.pinterest': 10.83,
  'com.reddit.frontpage': 11.04,
  'com.zhiliaoapp.musically': 15.81,
};

/// Human-readable app names keyed by Android package name.
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

/// Chart colours for each tracked app, used by the pie chart widget.
const Map<String, Color> kAppColors = {
  'com.google.android.youtube': Color(0xFFADD8E6),
  'tv.twitch.android.app': Color(0xFFFFB6C1),
  'com.twitter.android': Color(0xFF87CEFA),
  'com.linkedin.android': Color(0xFFB0E0E6),
  'com.facebook.katana': Color(0xFFFFA07A),
  'com.snapchat.android': Color(0xFFFFFF99),
  'com.instagram.android': Color(0xFFFFDAB9),
  'com.pinterest': Color(0xFFD8BFD8),
  'com.reddit.frontpage': Color(0xFFFF9999),
  'com.zhiliaoapp.musically': Color(0xFF98FB98),
};

/// The tracked app with the lowest CO₂ rate — the suggested substitution target.
const String kLowestCo2Package = 'com.google.android.youtube';

/// Returns the human-readable name for [packageName], or the raw package name
/// if it is not in the tracked set.
String appNameFromPackage(String packageName) =>
    kPackageToName[packageName] ?? packageName;

/// Formats [dt] as an ISO 8601 date string (YYYY-MM-DD).
String dateString(DateTime dt) =>
    '${dt.year.toString().padLeft(4, '0')}-'
    '${dt.month.toString().padLeft(2, '0')}-'
    '${dt.day.toString().padLeft(2, '0')}';

/// Returns the date exactly one calendar month before [date], clamping to the
/// last valid day of that month (e.g. March 31 → February 28, not March 3).
DateTime subtractOneMonth(DateTime date) {
  final year = date.month == 1 ? date.year - 1 : date.year;
  final month = date.month == 1 ? 12 : date.month - 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(year, month, day);
}
