import 'package:flutter/material.dart';
import '../services/usage_service.dart';

class PermissionCheckScreen extends StatefulWidget {
  const PermissionCheckScreen({Key? key}) : super(key: key);

  @override
  State<PermissionCheckScreen> createState() => _PermissionCheckScreenState();
}

class _PermissionCheckScreenState extends State<PermissionCheckScreen>
    with WidgetsBindingObserver {
  final UsageService _usageService = UsageService();

  bool _checkedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndNavigate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks permission when the user returns from the Settings screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndNavigate();
    }
  }

  Future<void> _checkPermissionAndNavigate() async {
    final hasPerm = await _usageService.hasUsagePermission();
    if (!mounted) return;

    setState(() => _checkedOnce = true);

    if (hasPerm) {
      // Navigate exactly once here — never inside build().
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showUsageAccessDialog();
    }
  }

  void _showUsageAccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usage Access Required'),
        content: const Text(
          'This app needs Usage Access to track your social media usage '
          'and calculate your digital carbon footprint. '
          'Please grant Usage Access on the next screen.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _usageService.openUsageSettings();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_checkedOnce ? 'Permission Required' : 'Checking Permissions…'),
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
