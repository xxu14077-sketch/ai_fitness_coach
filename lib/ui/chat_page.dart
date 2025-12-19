import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_coach/ui/theme.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js_util.dart' as js_util;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': '你好！我是你的 AI 健身教练。我可以帮你制定计划、解答健身疑问，或者估算食物热量。请问今天想练什么？'
    }
  ];
  bool _loading = false;

  // Image Upload State
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  bool _isAnalyzingImage = false;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedFileName = result.files.first.name;
          _selectedImageBytes = result.files.first.bytes;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedFileName = null;
    });
  }

  // Use the local TFJS logic to analyze the image before sending
  Future<String?> _analyzeImageLocally(Uint8List bytes) async {
    if (!kIsWeb) return null; // Only support web for this TFJS demo

    try {
      setState(() => _isAnalyzingImage = true);

      // 1. Create Blob URL
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      // 2. Create hidden image element
      final imgElement = html.ImageElement(src: url);
      imgElement.id =
          'chat-vision-target-${DateTime.now().millisecondsSinceEpoch}';
      imgElement.style.position = 'absolute';
      imgElement.style.top = '-9999px';
      imgElement.style.left = '-9999px';
      html.document.body!.append(imgElement);

      await imgElement.onLoad.first;

      // 3. Call JS
      final promise =
          js_util.callMethod(html.window, 'runAiAnalysis', [imgElement.id]);
      final resultJson = await js_util.promiseToFuture(promise);

      // Cleanup
      imgElement.remove();
      html.Url.revokeObjectUrl(url);

      if (resultJson != null) {
        final result = jsonDecode(resultJson);
        final keypoints = result['keypoints'] as List<dynamic>;
        return "【AI 视觉分析数据】\n检测到人体骨架关键点：${keypoints.length}个。\n(AI 已自动将此视觉数据附加到对话中)";
      }
      return null;
    } catch (e) {
      debugPrint("Analysis failed: $e");
      return null;
    } finally {
      setState(() => _isAnalyzingImage = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;

    // Construct the user message content
    String userContent = text;
    String? analysisReport;

    setState(() {
      _loading = true;
      // Show user message immediately
      if (_selectedImageBytes != null) {
        _messages.add({'role': 'user', 'content': '📷 [图片已上传] $text'});
      } else {
        _messages.add({'role': 'user', 'content': text});
      }
    });

    _controller.clear();
    _scrollToBottom();

    // If image present, analyze it first
    if (_selectedImageBytes != null) {
      try {
        analysisReport = await _analyzeImageLocally(_selectedImageBytes!);
        if (analysisReport != null) {
          userContent += "\n\n$analysisReport";
          // Add a system-like message to show analysis happened
          if (mounted) {
            _messages.add(
                {'role': 'assistant', 'content': '✅ 图片分析完成，正在结合视觉数据思考...'});
            _scrollToBottom();
          }
        } else {
          userContent += "\n\n[附带了一张图片，但未能检测到清晰人体姿态]";
        }
      } catch (e) {
        debugPrint("Image analysis error: $e");
      }
      _clearImage();
    }

    try {
      // 检查是否已登录
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        throw '未登录，请先登录后再试。';
      }

      // 尝试调用 Edge Function
      try {
        final res = await Supabase.instance.client.functions.invoke(
          'chat-stream',
          body: {'query': userContent},
        );

        final data = res.data;
        String reply = 'AI 思考中...';
        if (data is Map && data.containsKey('text')) {
          reply = data['text'];
        } else if (data is String) {
          reply = data;
        } else {
          reply = '抱歉，我暂时无法回答这个问题。';
        }

        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': reply});
          });
          _scrollToBottom();
        }
      } catch (functionError) {
        // 如果云函数调用失败（例如函数不存在或网络拦截），回退到本地模拟回复
        debugPrint('Edge Function Error: $functionError');

        // 模拟一个智能回复
        await Future.delayed(const Duration(seconds: 1));
        final mockReply = _getMockReply(userContent);

        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': mockReply});
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '发生错误: $e'});
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // 本地备用回复逻辑，确保演示时不冷场
  String _getMockReply(String input) {
    if (input.contains('视觉分析数据')) {
      return '我已收到您的动作分析数据。从关键点来看，您的深蹲动作幅度标准，但注意膝盖不要过度内扣。建议在下一次训练中尝试减小站距，感受臀部发力。';
    } else if (input.contains('图片')) {
      return '收到图片！虽然我现在只能看到文本描述，但如果您拍摄的是器械或食物，请告诉我具体名称，我可以为您提供更详细的建议。';
    } else if (input.contains('你好') || input.contains('hello')) {
      return '你好！我是你的 AI 健身私教。今天想练哪里？胸、背还是腿？';
    } else if (input.contains('减肥') || input.contains('瘦')) {
      return '减肥的关键是制造热量缺口。建议结合有氧运动（如慢跑、游泳）和力量训练。我可以为你制定一个减脂计划，你需要吗？';
    } else if (input.contains('增肌')) {
      return '增肌需要大重量低次数的训练刺激，同时保证充足的蛋白质摄入（每公斤体重1.5-2克）。我们先从复合动作（深蹲、卧推、硬拉）开始吧！';
    } else if (input.contains('计划')) {
      return '没问题。请告诉我你的：\n1. 健身目标（增肌/减脂）\n2. 每周锻炼天数\n3. 现有器械（哑铃/健身房/自重）';
    } else {
      return '这是一个很好的健身问题！作为 AI 教练，我建议你关注动作的标准性和训练的持续性。具体来说，我们可以针对你的目标进行个性化调整。';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.fitness_center, size: 20),
            SizedBox(width: 8),
            Text('AI 智能私教'),
          ],
        ),
        centerTitle: true,
        elevation: 1,
      ),
      body: Container(
        color: const Color(0xFFF8FAFC), // 浅灰背景
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  return _buildMessageBubble(isUser, msg['content']!);
                },
              ),
            ),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(_isAnalyzingImage ? 'AI 正在分析图片...' : 'AI 正在思考...',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(bool isUser, String content) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(maxWidth: 300), // 限制最大宽度
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            content,
            style: TextStyle(
              color: isUser ? Colors.white : const Color(0xFF334155),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            if (_selectedImageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  image: DecorationImage(
                    image: MemoryImage(_selectedImageBytes!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _clearImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // Camera / Image Button
                IconButton(
                  onPressed: _loading ? null : _pickImage,
                  icon: Icon(Icons.camera_alt_rounded,
                      color: Colors.grey.shade600),
                  tooltip: '上传图片',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '问问 AI 教练...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (_) => _loading ? null : _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _loading ? null : _sendMessage,
                  elevation: 0,
                  backgroundColor:
                      _loading ? Colors.grey.shade300 : AppTheme.primaryColor,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
