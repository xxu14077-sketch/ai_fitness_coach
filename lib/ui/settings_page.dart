import 'package:ai_fitness_coach/ui/knowledge_base_page.dart';
import 'package:ai_fitness_coach/ui/profile_page.dart';
import 'package:ai_fitness_coach/core/achievement_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_coach/ui/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _apiKeyController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _weeklyGoalController = TextEditingController();
  bool _isLoading = true;

  // Default DeepSeek Config
  static const String defaultBaseUrl = 'https://api.deepseek.com/v1';
  static const String defaultSystemPrompt = '''
你是一位专业的 AI 健身教练，拥有运动生理学、营养学和康复训练的深厚知识。
你的任务是：
1. 根据用户的目标制定科学的训练计划。
2. 解答关于动作规范、饮食搭配和补剂使用的问题。
3. 语气要积极、鼓励，但必须严谨专业。
4. 如果用户上传了图片，请结合视觉分析数据进行点评。
''';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Try to load from Supabase first
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      try {
        final res = await Supabase.instance.client
            .from('user_settings')
            .select()
            .eq('user_id', uid)
            .maybeSingle();

        if (res != null) {
          setState(() {
            _apiKeyController.text = res['ai_api_key'] ?? '';
            _baseUrlController.text = res['ai_base_url'] ?? defaultBaseUrl;
            _systemPromptController.text =
                res['ai_system_prompt'] ?? defaultSystemPrompt;
            _weeklyGoalController.text =
                (res['weekly_workout_goal'] ?? 4).toString();
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Load cloud settings error: $e');
      }
    }

    // Fallback to local
    setState(() {
      _apiKeyController.text = prefs.getString('ai_api_key') ?? '';
      _baseUrlController.text =
          prefs.getString('ai_base_url') ?? defaultBaseUrl;
      _systemPromptController.text =
          prefs.getString('ai_system_prompt') ?? defaultSystemPrompt;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final systemPrompt = _systemPromptController.text.trim();

    // Save local
    await prefs.setString('ai_api_key', apiKey);
    await prefs.setString('ai_base_url', baseUrl);
    await prefs.setString('ai_system_prompt', systemPrompt);

    // Save cloud
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      try {
        await Supabase.instance.client.from('user_settings').upsert({
          'user_id': uid,
          'ai_api_key': apiKey,
          'ai_base_url': baseUrl,
          'ai_system_prompt': systemPrompt,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Save cloud settings error: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存！AI 教练的大脑已更新 (本地+云端)。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 教练设置 (v1.3)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('🏆 目标设置', Icons.flag),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _weeklyGoalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每周训练目标 (天数)',
                      hintText: '4',
                      border: OutlineInputBorder(),
                      helperText: '设置您的每周目标，AI 会督促您完成！',
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('🧠 AI 模型配置', Icons.psychology),
                  const SizedBox(height: 16),
                  const Text(
                    '在此处配置您自己的 AI API Key (推荐 DeepSeek 或 OpenAI)，即可解锁完整的智能对话体验。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API 密钥 (API Key)',
                      hintText: 'sk-xxxxxxxx',
                      border: OutlineInputBorder(),
                      helperText: '您的密钥仅保存在本地设备，不会上传。',
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.deepseek.com/v1',
                      border: OutlineInputBorder(),
                      helperText: '默认为 DeepSeek 官方接口，也可使用 OpenAI 格式的转发地址。',
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader('📚 知识库与人设', Icons.menu_book),
                  const SizedBox(height: 16),

                  // New Profile Entry
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.person, color: Colors.orange),
                      title: const Text(
                        '个人档案 (Personal Memory)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('设置您的身高、体重、目标，AI 会记住并提供个性化建议。'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfilePage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // New Knowledge Base Entry
                  Card(
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading:
                          const Icon(Icons.library_books, color: Colors.blue),
                      title: const Text(
                        '私有知识库 (RAG Lite)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text('添加专属的训练文档、饮食规则，让 AI 更懂你。'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const KnowledgeBasePage()),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _systemPromptController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: '基础人设 (System Prompt)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      helperText: '这是 AI 的基础性格设定。特定知识请建议使用上方的“私有知识库”管理。',
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child:
                          const Text('保存并应用', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.secondaryColor,
          ),
        ),
      ],
    );
  }
}
