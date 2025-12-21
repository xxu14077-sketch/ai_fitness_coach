import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryService {
  static Future<String> getMemoryContext() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return '';

    final sb = StringBuffer();
    // Only add header if we actually find data, but easier to just add and return empty if no data found?
    // Let's build content first.
    String content = '';

    try {
      // 1. Fetch Profile
      final profile = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      
      if (profile != null) {
        content += '【基本档案】\n';
        if (profile['display_name'] != null) content += '- 称呼: ${profile['display_name']}\n';
        if (profile['gender'] != null) {
          final g = profile['gender'] == 'male' ? '男' : (profile['gender'] == 'female' ? '女' : '其他');
          content += '- 性别: $g\n';
        }
        if (profile['birth_year'] != null) {
           final age = DateTime.now().year - (profile['birth_year'] as int);
           content += '- 年龄: $age 岁\n';
        }
        if (profile['height_cm'] != null) content += '- 身高: ${profile['height_cm']}cm\n';
        if (profile['primary_goal'] != null) {
           final goalMap = {
             'muscle_gain': '增肌',
             'fat_loss': '减脂',
             'strength': '力量提升',
             'endurance': '耐力/心肺'
           };
           content += '- 主要目标: ${goalMap[profile['primary_goal']] ?? profile['primary_goal']}\n';
        }
        if (profile['injuries'] != null && (profile['injuries'] as String).isNotEmpty) {
           content += '- ⚠️ 伤病/禁忌: ${profile['injuries']}\n';
        }
      }

      // 2. Fetch Recent Metrics (Weight Trend)
      final metrics = await Supabase.instance.client
          .from('body_metrics')
          .select('date, weight_kg, body_fat_pct')
          .eq('user_id', uid)
          .order('date', ascending: false)
          .limit(3);
      
      if (metrics.isNotEmpty) {
        content += '\n【身体数据趋势 (最近3次)】\n';
        for (var m in metrics) {
          content += '- ${m['date']}: 体重 ${m['weight_kg']}kg' + (m['body_fat_pct'] != null ? ', 体脂 ${m['body_fat_pct']}%' : '') + '\n';
        }
      }

      // 3. Fetch Recent Workouts
      final workouts = await Supabase.instance.client
          .from('workout_sessions')
          .select('created_at, completion_pct, feedback_json')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(2);
      
      if (workouts.isNotEmpty) {
        content += '\n【最近训练状态】\n';
        for (var w in workouts) {
          final date = DateTime.parse(w['created_at']).toLocal().toString().substring(0, 10);
          final notes = (w['feedback_json'] as Map?)?['notes'] ?? '';
          content += '- $date: 完成度 ${w['completion_pct']}%' + (notes.isNotEmpty ? ', 备注: $notes' : '') + '\n';
        }
      }

    } catch (e) {
      // Fail silently
    }

    if (content.isEmpty) return '';

    sb.writeln('\n\n--- 用户个性化记忆 (Personalized Context) ---');
    sb.writeln('请基于以下用户真实历史数据进行个性化回答：');
    sb.write(content);
    sb.writeln('-------------------------------------------\n');
    
    return sb.toString();
  }
}
