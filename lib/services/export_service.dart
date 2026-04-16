import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'app_constants.dart';
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

  /// Loads all records once and returns both the CSV string and the row count.
  /// Throws if there is no data to export.
  Future<({String csv, int count})> _buildCsvWithCount() async {
    final records = await db.getAllUsageData();
    if (records.isEmpty) throw Exception('No data to export.');

    final buffer = StringBuffer();
    buffer.writeln('date,app_name,package_name,minutes,co2_grams,energy_mah');
    for (final r in records) {
      buffer.writeln(
        '${r.date},${r.appName},${r.packageName},'
        '${r.minutes.toStringAsFixed(2)},'
        '${r.co2Grams.toStringAsFixed(2)},'
        '${r.energyMah.toStringAsFixed(2)}',
      );
    }
    return (csv: buffer.toString(), count: records.length);
  }

  String _fileName() =>
      'carbon_footprint_data_${dateString(DateTime.now())}.csv';

  // ---------------------------------------------------------------------------
  // Option 1: Share via Android share sheet
  // ---------------------------------------------------------------------------

  /// Writes the CSV to a temp file and opens the system share sheet.
  /// Returns the number of records exported.
  Future<int> exportAndShare() async {
    final (:csv, :count) = await _buildCsvWithCount();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName()}');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Carbon Footprint Data Export — ${_fileName()}',
    );

    return count;
  }

  // ---------------------------------------------------------------------------
  // Option 2: Save directly to device storage
  // ---------------------------------------------------------------------------

  /// Saves the CSV to external storage (no permission required on Android 10+,
  /// accessible via file manager). Falls back to internal documents directory.
  /// Returns an [ExportResult] with the record count and the saved file path.
  Future<ExportResult> saveToDevice() async {
    final (:csv, :count) = await _buildCsvWithCount();

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
