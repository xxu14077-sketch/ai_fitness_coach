import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';

class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Cache
  int _currentStreak = 0;
  List<String> _unlockedIds = [];

  int get currentStreak => _currentStreak;
  List<String> get unlockedIds => _unlockedIds;

  Future<void> checkIn() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      // 1. Try to insert check-in
      await _client.from('daily_checkins').upsert(
        {'user_id': uid, 'date': today},
        onConflict: 'user_id, date',
      );

      // 2. Recalculate streak
      await _calculateStreak(uid);

      // 3. Check Milestones
      await _checkMilestones(uid);
    } catch (e) {
      debugPrint('Check-in error: $e');
    }
  }

  Future<void> _calculateStreak(String uid) async {
    // Get last 100 checkins
    final res = await _client
        .from('daily_checkins')
        .select('date')
        .eq('user_id', uid)
        .order('date', ascending: false)
        .limit(100);

    final List data = res as List;
    if (data.isEmpty) {
      _currentStreak = 0;
      return;
    }

    // Convert to DateTimes (midnight)
    final dates = data.map((e) {
      final d = DateTime.parse(e['date'] as String);
      return DateTime(d.year, d.month, d.day);
    }).toList();

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    // Check if the most recent checkin is today or yesterday
    final lastCheckin = dates.first;
    final diff = todayMidnight.difference(lastCheckin).inDays;

    if (diff > 1) {
      // Last checkin was before yesterday -> Streak broken
      _currentStreak = 0;
      return;
    }

    // Calculate consecutive days
    int streak = 1;
    for (int i = 0; i < dates.length - 1; i++) {
      final curr = dates[i];
      final prev = dates[i + 1];
      final d = curr.difference(prev).inDays;

      if (d == 1) {
        streak++;
      } else {
        break;
      }
    }

    _currentStreak = streak;
  }

  Future<List<String>> _checkMilestones(String uid) async {
    final milestones = {
      7: 'streak_7', // Advanced Coach
      30: 'streak_30', // Monthly Badge
      100: 'streak_100', // Fitness Expert
    };

    // Load unlocked
    final res = await _client
        .from('user_achievements')
        .select('achievement_id')
        .eq('user_id', uid);
    final unlocked =
        (res as List).map((e) => e['achievement_id'] as String).toSet();
    _unlockedIds = unlocked.toList();

    List<String> newUnlocks = [];

    for (final day in milestones.keys) {
      if (_currentStreak >= day) {
        final id = milestones[day]!;
        if (!unlocked.contains(id)) {
          // Unlock!
          await _client.from('user_achievements').insert({
            'user_id': uid,
            'achievement_id': id,
          });
          _unlockedIds.add(id);
          newUnlocks.add(id);

          // Trigger Notification
          String title = "🎉 成就解锁！";
          String body = "恭喜！您已连续打卡 $day 天。";
          if (day == 7) body += " 解锁「高级教练模式」！";
          if (day == 30) body += " 获得「月度标兵」徽章！";
          if (day == 100) body += " 荣获「健身达人」称号！";

          await NotificationService().show(title, body);
        }
      }
    }
    return newUnlocks;
  }

  // Weekly Goal Logic
  Future<Map<String, dynamic>> getWeeklyProgress() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {'current': 0, 'target': 3};

    // 1. Get Target
    int target = 4; // Default to 4
    try {
      final sRes = await _client
          .from('user_settings')
          .select('weekly_workout_goal')
          .eq('user_id', uid)
          .maybeSingle();
      if (sRes != null && sRes['weekly_workout_goal'] != null) {
        target = sRes['weekly_workout_goal'];
      }
    } catch (_) {}

    // 2. Count Workouts this week (Monday to Sunday)
    final now = DateTime.now();
    // Find previous Monday (or today if it's Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek =
        DateTime(monday.year, monday.month, monday.day).toIso8601String();

    final wRes = await _client
        .from('workout_sessions')
        .select('id')
        .eq('user_id', uid)
        .gte('created_at', startOfWeek)
        .count(CountOption.exact);

    final count = wRes.count;

    return {'current': count, 'target': target};
  }

  Future<void> setWeeklyGoal(int goal) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('user_settings').upsert({
      'user_id': uid,
      'weekly_workout_goal': goal,
      'updated_at': DateTime.now().toIso8601String(),
    },
        onConflict:
            'user_id'); // Ensure onConflict is handled if needed, usually upsert handles PK
  }
}
