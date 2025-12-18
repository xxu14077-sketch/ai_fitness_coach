import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ai_fitness_coach/ui/theme.dart';

class VisionPage extends StatefulWidget {
  const VisionPage({super.key});

  @override
  State<VisionPage> createState() => _VisionPageState();
}

class _VisionPageState extends State<VisionPage> {
  bool _analyzing = false;
  String? _analysisResult;
  String? _fileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result != null) {
      setState(() {
        _fileName = result.files.first.name;
        _analysisResult = null;
      });
    }
  }

  Future<void> _analyzeForm() async {
    if(_fileName == null) return;

    setState(() => _analyzing = true);
    
    // 模拟 AI 视觉分析过程
    // 实际项目中，这里会将文件上传到 Supabase Storage，并触发 Edge Function 调用 GPT-4o 或 Google Vision API
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _analyzing = false;
      _analysisResult = '''
【AI 视觉分析报告】
动作识别：深蹲 (Back Squat)

1. **✅ 优点**
   - 背部保持挺直，中立位控制良好。
   - 核心收紧，下蹲节奏平稳。

2. **⚠️ 风险点检测**
   - **膝盖内扣 (Knee Valgus)**: 在起立阶段，您的右膝有轻微向内塌陷。这通常是臀中肌力量不足的表现。
   - **下蹲深度**: 大腿略高于水平面，未达到全蹲深度。如果您的灵活性允许，建议蹲得更深一点以最大化臀腿刺激。

3. **🎯 纠正建议**
   - 训练前激活臀中肌（如弹力带螃蟹步）。
   - 尝试把脚尖稍微向外打开 15-30 度。
   - 意识控制：想象把地面向两侧“撕开”。
''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 动作矫正实验室')),
      body: Container(
        width: double.infinity,
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.camera_enhance_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '上传您的训练视频或照片\nAI 将分析您的动作规范性',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            // 上传区域
            InkWell(
              onTap: _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 48, color: AppTheme.primaryColor),
                    const SizedBox(height: 12),
                    Text(
                      _fileName ?? '点击选择文件',
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: _fileName != null ? Colors.black87 : AppTheme.primaryColor
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_fileName != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _analyzing ? null : _analyzeForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _analyzing
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('AI 正在逐帧分析...', style: TextStyle(color: Colors.white)),
                          ],
                        )
                      : const Text('开始分析', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),

            const SizedBox(height: 32),
            
            if (_analysisResult != null)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green),
                            SizedBox(width: 8),
                            Text('分析完成', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 24),
                        Text(_analysisResult!, style: const TextStyle(height: 1.6, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
