import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    setState(() {
      _apiKeyController.text = prefs.getString('ai_api_key') ?? '';
      _baseUrlController.text = prefs.getString('ai_base_url') ?? defaultBaseUrl;
      _systemPromptController.text = prefs.getString('ai_system_prompt') ?? defaultSystemPrompt;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_api_key', _apiKeyController.text.trim());
    await prefs.setString('ai_base_url', _baseUrlController.text.trim());
    await prefs.setString('ai_system_prompt', _systemPromptController.text.trim());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存！AI 教练的大脑已更新。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 教练设置')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      labelText: 'API Key',
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
                  _buildSectionHeader('📚 知识库与人设 (System Prompt)', Icons.menu_book),
                  const SizedBox(height: 16),
                  const Text(
                    '这就是您“喂”给 AI 的知识。您可以在这里定义它的性格、专业领域，甚至粘贴特定的训练法（如 5x5 力量训练法）。',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _systemPromptController,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: '系统提示词 (System Prompt)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
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
                      child: const Text('保存并应用', style: TextStyle(fontSize: 16)),
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
