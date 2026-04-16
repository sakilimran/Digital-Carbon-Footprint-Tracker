import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AppUsage {
  final int? id;
  final String date;           // YYYY-MM-DD
  final String packageName;
  final String appName;
  final double minutes;
  final double co2Grams;
  final double energyMah;
  final String recordedAt;     // ISO 8601 timestamp

  const AppUsage({
    this.id,
    required this.date,
    required this.packageName,
    required this.appName,
    required this.minutes,
    required this.co2Grams,
    required this.energyMah,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'package_name': packageName,
    'app_name': appName,
    'minutes': minutes,
    'co2_grams': co2Grams,
    'energy_mah': energyMah,
    'recorded_at': recordedAt,
  };

  factory AppUsage.fromMap(Map<String, dynamic> map) => AppUsage(
    id: map['id'] as int?,
    date: map['date'] as String,
    packageName: map['package_name'] as String,
    appName: map['app_name'] as String,
    minutes: (map['minutes'] as num).toDouble(),
    co2Grams: (map['co2_grams'] as num).toDouble(),
    energyMah: (map['energy_mah'] as num).toDouble(),
    recordedAt: map['recorded_at'] as String,
  );

  /// Convert to the Map format expected by existing UI widgets.
  Map<String, dynamic> toUsageMap() => {
    'package': packageName,
    'minutes': minutes,
    'co2': co2Grams,
    'energy': energyMah,
  };
}

class StoredRecommendation {
  final int? id;
  final String date;
  final String recommendationText;
  final String recommendationType;
  final double? potentialCo2Saving;
  final bool wasSeen;
  final String createdAt;

  const StoredRecommendation({
    this.id,
    required this.date,
    required this.recommendationText,
    required this.recommendationType,
    this.potentialCo2Saving,
    this.wasSeen = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'date': date,
    'recommendation_text': recommendationText,
    'recommendation_type': recommendationType,
    'potential_co2_saving': potentialCo2Saving,
    'was_seen': wasSeen ? 1 : 0,
    'created_at': createdAt,
  };

  factory StoredRecommendation.fromMap(Map<String, dynamic> map) =>
      StoredRecommendation(
        id: map['id'] as int?,
        date: map['date'] as String,
        recommendationText: map['recommendation_text'] as String,
        recommendationType: map['recommendation_type'] as String,
        potentialCo2Saving: map['potential_co2_saving'] != null
            ? (map['potential_co2_saving'] as num).toDouble()
            : null,
        wasSeen: (map['was_seen'] as int) == 1,
        createdAt: map['created_at'] as String,
      );
}

// ---------------------------------------------------------------------------
// Package name → friendly app name mapping
// ---------------------------------------------------------------------------

const Map<String, String> _packageToName = {
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

String appNameFromPackage(String packageName) =>
    _packageToName[packageName] ?? packageName;

// ---------------------------------------------------------------------------
// DatabaseService
// ---------------------------------------------------------------------------

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'carbon_footprint.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        minutes REAL NOT NULL,
        co2_grams REAL NOT NULL,
        energy_mah REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        UNIQUE(date, package_name)
      )
    ''');

    await db.execute('''
      CREATE TABLE recommendations_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        recommendation_text TEXT NOT NULL,
        recommendation_type TEXT NOT NULL,
        potential_co2_saving REAL,
        was_seen INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // -------------------------------------------------------------------------
  // daily_usage methods
  // -------------------------------------------------------------------------

  /// Upsert a full day's usage list. Existing entries for the same
  /// (date, package_name) are replaced with fresh values.
  Future<void> insertOrUpdateDailyUsage(
      String date, List<Map<String, dynamic>> usageList) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final batch = db.batch();
    for (final usage in usageList) {
      final packageName = usage['package'] as String;
      final entry = AppUsage(
        date: date,
        packageName: packageName,
        appName: appNameFromPackage(packageName),
        minutes: (usage['minutes'] as num).toDouble(),
        co2Grams: (usage['co2'] as num).toDouble(),
        energyMah: (usage['energy'] as num).toDouble(),
        recordedAt: now,
      );
      batch.insert(
        'daily_usage',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    debugPrint('DatabaseService: saved ${usageList.length} records for $date');
  }

  /// Returns all usage records for a single date (YYYY-MM-DD).
  Future<List<AppUsage>> getDailyUsage(String date) async {
    final db = await database;
    final rows = await db.query(
      'daily_usage',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.map(AppUsage.fromMap).toList();
  }

  /// Returns all usage records between startDate and endDate (inclusive),
  /// ordered by date. Each row is one app on one day (not aggregated).
  Future<List<AppUsage>> getUsageRange(
      String startDate, String endDate) async {
    final db = await database;
    final rows = await db.query(
      'daily_usage',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
    return rows.map(AppUsage.fromMap).toList();
  }

  /// Returns all usage records for the last [days] days (today inclusive).
  /// Useful for the AI recommendation engine.
  Future<List<AppUsage>> getLastNDaysUsage(int days) async {
    final now = DateTime.now();
    final startDate =
        now.subtract(Duration(days: days - 1));
    final startStr = _dateString(startDate);
    final endStr = _dateString(now);
    return getUsageRange(startStr, endStr);
  }

  /// Returns every record in the database, ordered by date.
  /// Used for CSV export.
  Future<List<AppUsage>> getAllUsageData() async {
    final db = await database;
    final rows = await db.query('daily_usage', orderBy: 'date ASC');
    return rows.map(AppUsage.fromMap).toList();
  }

  /// Aggregates usage records for a date range by package, returning
  /// a list in the same Map format the existing UI widgets expect:
  /// {package, minutes, co2, energy}.
  Future<List<Map<String, dynamic>>> getAggregatedUsageForRange(
      String startDate, String endDate) async {
    final records = await getUsageRange(startDate, endDate);
    if (records.isEmpty) return [];

    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final r in records) {
      if (!aggregated.containsKey(r.packageName)) {
        aggregated[r.packageName] = {
          'package': r.packageName,
          'minutes': 0.0,
          'co2': 0.0,
          'energy': 0.0,
        };
      }
      aggregated[r.packageName]!['minutes'] =
          (aggregated[r.packageName]!['minutes'] as double) + r.minutes;
      aggregated[r.packageName]!['co2'] =
          (aggregated[r.packageName]!['co2'] as double) + r.co2Grams;
      aggregated[r.packageName]!['energy'] =
          (aggregated[r.packageName]!['energy'] as double) + r.energyMah;
    }
    return aggregated.values.toList();
  }

  /// Returns the distinct dates stored in the database.
  Future<int> countStoredDays() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(DISTINCT date) as cnt FROM daily_usage');
    return (result.first['cnt'] as int?) ?? 0;
  }

  // -------------------------------------------------------------------------
  // recommendations_log methods
  // -------------------------------------------------------------------------

  Future<void> insertRecommendation({
    required String date,
    required String recommendationText,
    required String recommendationType,
    double? potentialCo2Saving,
  }) async {
    final db = await database;
    final rec = StoredRecommendation(
      date: date,
      recommendationText: recommendationText,
      recommendationType: recommendationType,
      potentialCo2Saving: potentialCo2Saving,
      createdAt: DateTime.now().toIso8601String(),
    );
    await db.insert('recommendations_log', rec.toMap());
  }

  Future<List<StoredRecommendation>> getRecommendationsForDate(
      String date) async {
    final db = await database;
    final rows = await db.query(
      'recommendations_log',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'created_at DESC',
    );
    return rows.map(StoredRecommendation.fromMap).toList();
  }

  // -------------------------------------------------------------------------
  // Privacy / reset
  // -------------------------------------------------------------------------

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('daily_usage');
    await db.delete('recommendations_log');
    debugPrint('DatabaseService: all data deleted');
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _dateString(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
