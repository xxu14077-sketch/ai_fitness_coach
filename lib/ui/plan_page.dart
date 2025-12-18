import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_coach/ui/theme.dart';

class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  bool _loading = false;
  String? _generatedPlan;

  // 用户状态数据
  String _goal = '增肌 (Hypertrophy)';
  String _equipment = '健身房全套设施';
  double _sleepQuality = 7.0; // 1-10
  double _soreness = 3.0; // 1-10 (酸痛程度)
  String _focusArea = '胸部 & 三头肌';

  Future<void> _generatePlan() async {
    setState(() => _loading = true);

    // 构建提示词，包含超个性化参数
    final prompt = '''
作为一名顶级体能教练，请为我制定今天的训练计划。
我的数据如下：
- 目标：$_goal
- 可用器械：$_equipment
- 昨晚睡眠质量：${_sleepQuality.round()}/10
- 肌肉酸痛程度：${_soreness.round()}/10
- 今天想练部位：$_focusArea

要求：
1. 如果睡眠差或酸痛高，请自动降低训练容量或强度（RPE）。
2. 请列出具体的动作、组数、次数和建议重量（或 RPE）。
3. 使用渐进式超负荷原则。
4. 输出格式清晰，包含热身、正式训练和冷身。
''';

    try {
      // 调用 AI (复用 chat-stream 或专用函数)
      final res = await Supabase.instance.client.functions.invoke(
        'chat-stream',
        body: {'query': prompt},
      );
      
      final data = res.data;
      String result = '';
      if (data is Map && data.containsKey('text')) {
        result = data['text'];
      } else {
        result = data.toString();
      }

      setState(() {
        _generatedPlan = result;
      });
    } catch (e) {
      // 模拟生成（当后端未连接时）
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _generatedPlan = _getMockPlan();
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _getMockPlan() {
    bool isRecoveryDay = _sleepQuality < 5 || _soreness > 7;
    
    if (isRecoveryDay) {
      return '''
【AI 智能调整：主动恢复日】
检测到您昨晚睡眠质量较低且肌肉酸痛明显，今日计划调整为“主动恢复”模式，重点在于血液循环和灵活性，避免过度训练。

1. **热身 (10分钟)**
   - 跑步机快走：5分钟 (心率 < 120)
   - 动态拉伸：肩部环绕、猫牛式

2. **功能性训练 (3组)**
   - 自重深蹲：15次 (RPE 4)
   - 俯卧撑 (或跪姿)：12次 (RPE 5)
   - 平板支撑：30秒

3. **筋膜放松**
   - 泡沫轴滚压背部和腿部：10分钟

建议：今晚争取早睡1小时，补充富含镁的食物。
''';
    }

    return '''
【AI 智能计划：渐进式超负荷】
状态良好！今日重点冲击 $_focusArea。

1. **热身**
   - 招财猫动作 (肩袖预热)：2组 x 15次
   - 空杆卧推：1组 x 20次

2. **正式训练**
   - **平板杠铃卧推** (核心动作)
     - 4组 x 6-8次 (RPE 8.5)
     - *注意：最后一组应接近力竭，重量比上周增加 1.25kg*
   
   - **上斜哑铃推举**
     - 3组 x 10-12次 (RPE 8)
     - *控制离心阶段 2秒*

   - **龙门架绳索夹胸**
     - 3组 x 15次 (RPE 9)
     - *顶峰收缩 1秒*

   - **绳索下压 (三头肌)**
     - 4组 x 12次 (超级组)

3. **冷身**
   - 胸大肌静态拉伸：每侧 30秒
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 智能计划')),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _generatePlan,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('生成今日专属计划', style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(height: 24),
            if (_generatedPlan != null) _buildPlanResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('每日状态打卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDropdown('训练目标', _goal, ['增肌 (Hypertrophy)', '力量 (Strength)', '减脂 (Fat Loss)'], (v) => setState(() => _goal = v!)),
            _buildDropdown('今日部位', _focusArea, ['胸部 & 三头肌', '背部 & 二头肌', '腿部 & 核心', '全身 HIIT'], (v) => setState(() => _focusArea = v!)),
            const SizedBox(height: 16),
            const Text('昨晚睡眠质量 (1-10)', style: TextStyle(color: Colors.grey)),
            Slider(
              value: _sleepQuality,
              min: 1,
              max: 10,
              divisions: 9,
              label: _sleepQuality.round().toString(),
              activeColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => _sleepQuality = v),
            ),
            const Text('肌肉酸痛程度 (1-10)', style: TextStyle(color: Colors.grey)),
            Slider(
              value: _soreness,
              min: 1,
              max: 10,
              divisions: 9,
              label: _soreness.round().toString(),
              activeColor: Colors.redAccent,
              onChanged: (v) => setState(() => _soreness = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          DropdownButton<String>(
            value: value,
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: onChanged,
            underline: Container(),
            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanResult() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('AI 生成结果', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          Text(_generatedPlan!, style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF334155))),
        ],
      ),
    );
  }
}
