import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({super.key});

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  List<int> _activityLevels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 84 days = 12 weeks
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 83));

      final res = await Supabase.instance.client
          .from('workout_sessions')
          .select('created_at, completion_pct')
          .eq('user_id', uid)
          .gte('created_at', startDate.toIso8601String());

      final List<dynamic> records = res as List;

      // Map date string (YYYY-MM-DD) to max completion pct
      final Map<String, int> dailyMax = {};

      for (var r in records) {
        final dateStr = (r['created_at'] as String).substring(0, 10);
        final pct = (r['completion_pct'] as int?) ?? 0;
        if (!dailyMax.containsKey(dateStr) || pct > dailyMax[dateStr]!) {
          dailyMax[dateStr] = pct;
        }
      }

      // Generate last 84 days levels
      final List<int> levels = [];
      for (int i = 0; i < 84; i++) {
        final d = startDate.add(Duration(days: i));
        final key = d.toIso8601String().substring(0, 10);

        if (dailyMax.containsKey(key)) {
          final pct = dailyMax[key]!;
          if (pct > 80) {
            levels.add(3);
          } else if (pct > 50) {
            levels.add(2);
          } else {
            levels.add(1);
          }
        } else {
          levels.add(0);
        }
      }

      if (mounted) {
        setState(() {
          _activityLevels = levels;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Heatmap error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    if (_activityLevels.isEmpty) return const SizedBox();

    // Calculate streak (simple version: count backwards from today until 0)
    int streak = 0;
    for (int i = _activityLevels.length - 1; i >= 0; i--) {
      if (_activityLevels[i] > 0) {
        streak++;
      } else {
        // Allow 1 day gap? No, strict streak for now.
        // If today is empty, check yesterday.
        if (i == _activityLevels.length - 1) continue;
        break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '训练活跃度',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
              ),
              Text(
                '连续 $streak 天',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120, // Fixed height for the grid
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // Show newest on the right
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, // 7 days a week (rows)
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemCount: _activityLevels.length,
              itemBuilder: (context, index) {
                final level = _activityLevels[index];
                return Container(
                  decoration: BoxDecoration(
                    color: _getColorForLevel(level),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less ',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              _buildLegendBox(0),
              const SizedBox(width: 2),
              _buildLegendBox(1),
              const SizedBox(width: 2),
              _buildLegendBox(2),
              const SizedBox(width: 2),
              _buildLegendBox(3),
              const Text(' More',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBox(int level) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _getColorForLevel(level),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 0:
        return Colors.grey.shade200;
      case 1:
        return AppTheme.primaryColor.withOpacity(0.3);
      case 2:
        return AppTheme.primaryColor.withOpacity(0.6);
      case 3:
        return AppTheme.primaryColor;
      default:
        return Colors.grey.shade200;
    }
  }
}
