import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';

class ExportResult {
  final int recordCount;
  final String filePath;

  const ExportResult({required this.recordCount, required this.filePath});
}

class ExportService {
  final DatabaseService db;

  const ExportService({required this.db});

  // ---------------------------------------------------------------------------
  // CSV generation
  // ---------------------------------------------------------------------------

  Future<String> _buildCsv() async {
    final records = await db.getAllUsageData();
    final buffer = StringBuffer();
    buffer.writeln('date,app_name,package_name,minutes,co2_grams,energy_mah');
    for (final r in records) {
      buffer.writeln(
        '${r.date},'
        '${r.appName},'
        '${r.packageName},'
        '${r.minutes.toStringAsFixed(2)},'
        '${r.co2Grams.toStringAsFixed(2)},'
        '${r.energyMah.toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  String _fileName() {
    final dt = DateTime.now();
    final dateStr =
        '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
    return 'carbon_footprint_data_$dateStr.csv';
  }

  Future<int> _assertHasData() async {
    final records = await db.getAllUsageData();
    if (records.isEmpty) throw Exception('No data to export.');
    return records.length;
  }

  // ---------------------------------------------------------------------------
  // Option 1: Share via Android share sheet
  // ---------------------------------------------------------------------------

  /// Builds the CSV, writes it to a temp file, and opens the share sheet.
  /// Returns the number of records exported.
  Future<int> exportAndShare() async {
    final count = await _assertHasData();
    final csv = await _buildCsv();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName()}');
    await file.writeAsString(csv);

    debugPrint('ExportService: sharing ${file.path}');

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Carbon Footprint Data Export — ${_fileName()}',
    );

    return count;
  }

  // ---------------------------------------------------------------------------
  // Option 2: Save directly to device storage
  // ---------------------------------------------------------------------------

  /// Saves the CSV to the app's external documents directory (no permission
  /// required on Android 10+). Returns an [ExportResult] with the record count
  /// and the full file path where it was saved.
  Future<ExportResult> saveToDevice() async {
    final count = await _assertHasData();
    final csv = await _buildCsv();

    // Try external storage first (accessible via file managers on Android).
    // Fall back to internal documents directory if external is unavailable.
    Directory? dir;
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {
      dir = null;
    }
    dir ??= await getApplicationDocumentsDirectory();

    final file = File('${dir.path}/${_fileName()}');
    await file.writeAsString(csv);

    debugPrint('ExportService: saved to ${file.path}');

    return ExportResult(recordCount: count, filePath: file.path);
  }
}
