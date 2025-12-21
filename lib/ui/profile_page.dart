import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_coach/ui/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _injuriesCtrl = TextEditingController();
  
  String _gender = 'male';
  String _primaryGoal = 'muscle_gain';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('user_profiles')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _nameCtrl.text = res['display_name'] ?? '';
          if (res['birth_year'] != null) {
            _ageCtrl.text = (DateTime.now().year - (res['birth_year'] as int)).toString();
          }
          _heightCtrl.text = (res['height_cm'] ?? '').toString();
          _injuriesCtrl.text = res['injuries'] ?? '';
          _gender = res['gender'] ?? 'male';
          _primaryGoal = res['primary_goal'] ?? 'muscle_gain';
        });
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final age = int.tryParse(_ageCtrl.text);
    final birthYear = age != null ? DateTime.now().year - age : null;
    final height = int.tryParse(_heightCtrl.text);

    try {
      await Supabase.instance.client.from('user_profiles').upsert({
        'user_id': uid,
        'display_name': _nameCtrl.text.trim(),
        'birth_year': birthYear,
        'gender': _gender,
        'height_cm': height,
        'primary_goal': _primaryGoal,
        'injuries': _injuriesCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('个人档案已保存！AI 将记住这些信息。')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('个人档案')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('完善您的个人档案，让 AI 提供更精准的建议。', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '昵称 / 称呼',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ageCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '年龄',
                              border: OutlineInputBorder(),
                              suffixText: '岁',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _gender,
                            decoration: const InputDecoration(
                              labelText: '性别',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('男')),
                              DropdownMenuItem(value: 'female', child: Text('女')),
                              DropdownMenuItem(value: 'other', child: Text('其他')),
                            ],
                            onChanged: (val) => setState(() => _gender = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '身高',
                        border: OutlineInputBorder(),
                        suffixText: 'cm',
                        prefixIcon: Icon(Icons.height),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _primaryGoal,
                      decoration: const InputDecoration(
                        labelText: '主要健身目标',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'muscle_gain', child: Text('增肌 (Muscle Gain)')),
                        DropdownMenuItem(value: 'fat_loss', child: Text('减脂 (Fat Loss)')),
                        DropdownMenuItem(value: 'strength', child: Text('力量提升 (Strength)')),
                        DropdownMenuItem(value: 'endurance', child: Text('心肺耐力 (Endurance)')),
                      ],
                      onChanged: (val) => setState(() => _primaryGoal = val!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _injuriesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '伤病史 / 禁忌动作 (选填)',
                        border: OutlineInputBorder(),
                        hintText: '例如：左膝盖半月板损伤，不能做深蹲...',
                        prefixIcon: Icon(Icons.medical_services),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('保存档案', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
