import 'package:flutter/material.dart';
import '../services/app_constants.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../widgets/app_drawer.dart';

class DataManagementPage extends StatefulWidget {
  const DataManagementPage({Key? key}) : super(key: key);

  @override
  State<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends State<DataManagementPage> {
  final ExportService _exportService = ExportService(db: DatabaseService());
  final DatabaseService _db = DatabaseService();

  bool _isSharing = false;
  bool _isSaving = false;
  bool _isClearing = false;

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _onShareTapped() async {
    final confirmed = await _showConfirmDialog(
      title: 'Share CSV',
      message: 'This will export your usage history as a CSV file. '
          'No personal identification data is included.',
      confirmLabel: 'Share',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSharing = true);
    try {
      final count = await _exportService.exportAndShare();
      if (mounted) _showSnackBar('Exported $count records via share sheet.');
    } catch (e) {
      if (mounted) _showSnackBar('Export failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _onSaveTapped() async {
    final confirmed = await _showConfirmDialog(
      title: 'Save to Device',
      message: 'The CSV file will be saved to your device storage. '
          'You can find it in your file manager under the app folder.',
      confirmLabel: 'Save',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final result = await _exportService.saveToDevice();
      if (mounted) {
        _showSnackBar(
          '${result.recordCount} records saved to:\n${result.filePath}',
          duration: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Save failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onClearTapped() async {
    final confirmed = await _showConfirmDialog(
      title: 'Clear All Data',
      message: 'This will permanently delete all stored usage data. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isClearing = true);
    try {
      await _db.deleteAllData();
      if (mounted) _showSnackBar('All data has been deleted.');
    } catch (e) {
      if (mounted) _showSnackBar('Failed to clear data: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message,
      {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Export section ----
            _sectionTitle('Export Data'),
            const SizedBox(height: 8),
            const Text(
              'Export your complete usage history as a CSV file for research '
              'purposes. No personal identification data is included — only '
              'app names, usage times, and calculated emissions.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),

            // Share button
            _actionButton(
              label: 'Share CSV',
              sublabel: 'Open share sheet to send via email, Drive, etc.',
              icon: Icons.share,
              isLoading: _isSharing,
              onPressed: _onShareTapped,
            ),
            const SizedBox(height: 12),

            // Save to device button
            _actionButton(
              label: 'Save to Device',
              sublabel: 'Save CSV directly to device storage',
              icon: Icons.download,
              isLoading: _isSaving,
              onPressed: _onSaveTapped,
            ),

            const SizedBox(height: 36),
            const Divider(),
            const SizedBox(height: 20),

            // ---- Privacy section ----
            _sectionTitle('Privacy'),
            const SizedBox(height: 8),
            const Text(
              'All data is stored locally on this device and is never uploaded '
              'automatically. You can permanently delete all stored data at any time.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),

            // Clear data button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isClearing ? null : _onClearTapped,
                icon: _isClearing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever, color: Colors.red),
                label: Text(
                  _isClearing ? 'Clearing…' : 'Clear All Data',
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      );

  Widget _actionButton({
    required String label,
    required String sublabel,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          children: [
            isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black54),
                  )
                : Icon(icon, size: 22),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sublabel,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
