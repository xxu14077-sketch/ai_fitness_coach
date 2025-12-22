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
      final startDateStr = startDate.toIso8601String().substring(0, 10);

      // 1. Fetch Workouts
      final wRes = await Supabase.instance.client
          .from('workout_sessions')
          .select('created_at, completion_pct')
          .eq('user_id', uid)
          .gte('created_at', startDateStr);

      // 2. Fetch Body Metrics
      final bRes = await Supabase.instance.client
          .from('body_metrics')
          .select('date')
          .eq('user_id', uid)
          .gte('date', startDateStr);

      // 3. Fetch Strength Progress
      final sRes = await Supabase.instance.client
          .from('strength_progress')
          .select('date')
          .eq('user_id', uid)
          .gte('date', startDateStr);

      final Map<String, int> dailyScore = {};

      // Process Workouts (High Value)
      for (var r in (wRes as List)) {
        final dateStr = (r['created_at'] as String).substring(0, 10);
        final pct = (r['completion_pct'] as int?) ?? 0;
        final score = pct > 80 ? 3 : (pct > 50 ? 2 : 1);

        if (!dailyScore.containsKey(dateStr) || score > dailyScore[dateStr]!) {
          dailyScore[dateStr] = score;
        }
      }

      // Process Body Metrics (Medium Value)
      for (var r in (bRes as List)) {
        final dateStr = r['date'] as String;
        // Recording weight is a valid activity (Level 1-2)
        if (!dailyScore.containsKey(dateStr) || dailyScore[dateStr]! < 2) {
          dailyScore[dateStr] = 2;
        }
      }

      // Process Strength (High Value)
      for (var r in (sRes as List)) {
        final dateStr = r['date'] as String;
        // Lifting is a high activity (Level 3)
        dailyScore[dateStr] = 3;
      }

      // Generate last 84 days levels
      final List<int> levels = [];
      for (int i = 0; i < 84; i++) {
        final d = startDate.add(Duration(days: i));
        final key = d.toIso8601String().substring(0, 10);

        if (dailyScore.containsKey(key)) {
          levels.add(dailyScore[key]!);
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
    bool todayChecked = false;
    if (_activityLevels.isNotEmpty) {
      if (_activityLevels.last > 0) todayChecked = true;

      for (int i = _activityLevels.length - 1; i >= 0; i--) {
        if (_activityLevels[i] > 0) {
          streak++;
        } else {
          if (i == _activityLevels.length - 1) continue;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '每日打卡',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    todayChecked ? '今日已打卡 ✅' : '今日未打卡',
                    style: TextStyle(
                      fontSize: 12,
                      color: todayChecked ? Colors.green : Colors.grey,
                      fontWeight:
                          todayChecked ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$streak 天连胜',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
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
              const Text('少 ',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
              _buildLegendBox(0),
              const SizedBox(width: 2),
              _buildLegendBox(1),
              const SizedBox(width: 2),
              _buildLegendBox(2),
              const SizedBox(width: 2),
              _buildLegendBox(3),
              const Text(' 多',
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
