import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/recommendation_engine.dart';
import '../widgets/app_drawer.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({Key? key}) : super(key: key);

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  final RecommendationEngine _engine =
      RecommendationEngine(db: DatabaseService());

  List<Recommendation> _recommendations = [];
  bool _isLoading = true;
  bool _hasEnoughData = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);
    try {
      final storedDays = await DatabaseService().countStoredDays();
      if (storedDays < 3) {
        setState(() {
          _hasEnoughData = false;
          _isLoading = false;
        });
        return;
      }

      final recs = await _engine.generateRecommendations();
      setState(() {
        _recommendations = recs;
        _hasEnoughData = true;
      });
    } catch (e) {
      debugPrint('RecommendationsPage error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Tips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh recommendations',
            onPressed: _loadRecommendations,
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasEnoughData) {
      return _buildInsufficientDataState();
    }

    if (_recommendations.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        ..._recommendations.map(_buildCard),
      ],
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Personalised tips based on your usage patterns. '
      'Keep using the app daily to improve recommendation accuracy.',
      style: TextStyle(fontSize: 14, color: Colors.black54),
    );
  }

  Widget _buildCard(Recommendation rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBDA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFB3D48E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _iconForType(rec.type, rec.title),
                size: 24,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 14),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rec.body,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  if (rec.potentialSaving != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB3D48E),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Save ~${rec.potentialSaving!.toStringAsFixed(1)}g CO₂',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsufficientDataState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top,
                size: 72, color: Colors.black.withValues(alpha: 0.25)),
            const SizedBox(height: 24),
            const Text(
              'Almost there!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Keep using the app for a few more days to receive '
              'personalised recommendations based on your usage patterns.',
              style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 72, color: Colors.black.withValues(alpha: 0.25)),
            const SizedBox(height: 24),
            const Text(
              'Looking good!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'No specific recommendations right now. '
              'Your usage patterns look balanced — keep it up!',
              style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type, String title) {
    switch (type) {
      case 'substitution':
        return Icons.swap_horiz;
      case 'trend':
        return title.toLowerCase().contains('great') ||
                title.toLowerCase().contains('dropped')
            ? Icons.trending_down
            : Icons.trending_up;
      case 'budget':
        return Icons.timer_outlined;
      case 'equivalence':
        return Icons.eco_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }
}
