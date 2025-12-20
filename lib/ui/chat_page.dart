import 'package:ai_fitness_coach/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ai_fitness_coach/ui/theme.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data'; // For Uint8List
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js_util.dart' as js_util;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown/markdown.dart' as md;

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [
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

  // AI Service Config
  String? _apiKey;
  String? _baseUrl;
  String? _systemPrompt;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadAiConfig();
    await _loadMessages();
  }

  Future<void> _loadAiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('ai_api_key');
      _baseUrl = prefs.getString('ai_base_url');
      _systemPrompt = prefs.getString('ai_system_prompt');
    });
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('chat_history');
    if (saved != null) {
      setState(() {
        _messages =
            saved.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _messages.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('chat_history', list);
  }

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

  Future<String?> _analyzeImageLocally(Uint8List bytes) async {
    if (!kIsWeb) return null;

    try {
      setState(() => _isAnalyzingImage = true);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final imgElement = html.ImageElement(src: url);
      imgElement.id =
          'chat-vision-target-${DateTime.now().millisecondsSinceEpoch}';
      imgElement.style.position = 'absolute';
      imgElement.style.top = '-9999px';
      imgElement.style.left = '-9999px';
      html.document.body!.append(imgElement);
      await imgElement.onLoad.first;
      final promise =
          js_util.callMethod(html.window, 'runAiAnalysis', [imgElement.id]);
      final resultJson = await js_util.promiseToFuture(promise);
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

  Future<String> _callAiApi(String userContent) async {
    await _loadAiConfig();

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw '请先在右上角的设置中配置 API Key (如 DeepSeek)。';
    }

    final url = _baseUrl ?? 'https://api.deepseek.com/v1';
    final systemPrompt = _systemPrompt ??
        'You are a helpful fitness coach. Please formatting your response with Markdown.';

    final List<Map<String, dynamic>> apiMessages = [
      {'role': 'system', 'content': systemPrompt},
      ..._messages
          .take(10)
          .map((m) => {'role': m['role'], 'content': m['content']}),
    ];

    var apiUrl = Uri.parse('$url/chat/completions');

    // CORS PROXY LOGIC FOR WEB
    if (kIsWeb) {
      if (url.contains('api.deepseek.com')) {
        final path = Uri.parse(url).path;
        apiUrl = Uri.parse('/api/deepseek$path/chat/completions');
      } else if (url.contains('api.openai.com')) {
        final path = Uri.parse(url).path;
        apiUrl = Uri.parse('/api/openai$path/chat/completions');
      }
    }

    try {
      final response = await http.post(
        apiUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'deepseek-chat',
          'messages': apiMessages,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        throw 'API Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      throw '连接 AI 失败: $e';
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;

    String userContent = text;

    setState(() {
      _loading = true;
      if (_selectedImageBytes != null) {
        _messages.add({'role': 'user', 'content': '📷 [图片已上传] $text'});
      } else {
        _messages.add({'role': 'user', 'content': text});
      }
    });
    _saveMessages(); // Save user message

    _controller.clear();
    _scrollToBottom();

    if (_selectedImageBytes != null) {
      try {
        final analysisReport = await _analyzeImageLocally(_selectedImageBytes!);
        if (analysisReport != null) {
          userContent += "\n\n$analysisReport";
          if (mounted) {
            setState(() {
              _messages.add(
                  {'role': 'assistant', 'content': '✅ 图片分析完成，正在结合视觉数据思考...'});
            });
            _saveMessages();
            _scrollToBottom();
          }
        }
      } catch (e) {
        debugPrint("Image analysis error: $e");
      }
      _clearImage();
    }

    try {
      await _loadAiConfig();

      if (_apiKey != null && _apiKey!.isNotEmpty) {
        final reply = await _callAiApi(userContent);
        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': reply});
          });
          _saveMessages(); // Save AI reply
        }
      } else {
        await Future.delayed(const Duration(seconds: 1));
        final mockReply = _getMockReply(userContent);
        if (mounted) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': mockReply});
            if (_messages.length < 5) {
              _messages.add({
                'role': 'system',
                'content': '💡 提示：点击右上角设置图标，配置 DeepSeek API Key 即可体验真正的 AI 智能。'
              });
            }
          });
          _saveMessages();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '⚠️ $e'});
        });
        _saveMessages();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('chat_history');
              setState(() {
                _messages = [
                  {
                    'role': 'assistant',
                    'content':
                        '你好！我是你的 AI 健身教练。我可以帮你制定计划、解答健身疑问，或者估算食物热量。请问今天想练什么？'
                  }
                ];
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
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
                  final role = msg['role'];
                  if (role == 'system') {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                          child: Text(msg['content']!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey))),
                    );
                  }
                  final isUser = role == 'user';
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
        constraints: const BoxConstraints(maxWidth: 320), // 稍微调宽一点
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
          child: MarkdownBody(
            data: content,
            selectable: true,
            // 启用 GitHub 风格的 Markdown (支持表格、删除线等)
            extensionSet: md.ExtensionSet.gitHubFlavored,
            styleSheet: MarkdownStyleSheet(
              // 普通文本
              p: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF334155),
                fontSize: 15,
                height: 1.5,
              ),
              // 粗体
              strong: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              // 斜体
              em: TextStyle(
                color: isUser ? Colors.white70 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
              // 列表项
              listBullet: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
              ),
              // 标题
              h1: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              h2: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              h3: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              // 代码块
              code: TextStyle(
                backgroundColor: isUser ? Colors.black26 : Colors.grey.shade100,
                color: isUser ? Colors.white : Colors.red,
                fontFamily: 'monospace',
              ),
              codeblockDecoration: BoxDecoration(
                color: isUser ? Colors.black26 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              // 表格
              tableHead: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              tableBody: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF334155),
              ),
              tableBorder: TableBorder.all(
                color: isUser ? Colors.white30 : Colors.grey.shade300,
              ),
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
                      minLines: 1,
                      maxLines: 4, // Allow multiline input
                      decoration: const InputDecoration(
                        hintText: '问问 AI 教练...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      // onSubmitted handles only single line usually, but for chat apps often good to keep.
                      // But with maxLines > 1, Enter usually means new line.
                      // Let's keep it simple: Text Field grows, send button is primary trigger.
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
