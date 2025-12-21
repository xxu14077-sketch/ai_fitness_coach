import 'package:ai_fitness_coach/ui/settings_page.dart';
import 'package:ai_fitness_coach/ui/chat_history_drawer.dart';
import 'package:ai_fitness_coach/ui/knowledge_base_page.dart';
import 'package:ai_fitness_coach/core/memory_service.dart'; // Import Memory Service
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:ai_fitness_coach/ui/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js_util.dart' as js_util;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt; // STT
import 'package:flutter_tts/flutter_tts.dart'; // TTS

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --- Voice Interaction State ---
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastWords = '';
  // -------------------------------

  // --- Session Management ---
  List<ChatSession> _sessions = [];
  String _currentSessionId = '';
  // --------------------------

  // --- Knowledge Base (RAG Lite) ---
  List<KnowledgeEntry> _knowledgeEntries = [];
  // ---------------------------------

  List<Map<String, String>> _messages = [];
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
    _initializeData();
    _initVoice(); // Initialize Voice
  }

  // --- Voice Initialization ---
  void _initVoice() async {
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();

    if (kIsWeb) {
      // Web TTS settings
      await _flutterTts.setLanguage("zh-CN");
      await _flutterTts.setSpeechRate(1.0);
    } else {
      // Mobile TTS settings
      await _flutterTts.setLanguage("zh-CN");
      await _flutterTts.setPitch(1.0);
    }

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  // --- STT Logic ---
  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('onStatus: $val');
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
            // Auto send if we have words
            if (_lastWords.isNotEmpty) {
              _controller.text = _lastWords;
              _sendMessage(); // Auto send after listening
            }
          }
        },
        onError: (val) => debugPrint('onError: $val'),
      );

      if (available) {
        setState(() => _isListening = true);
        _lastWords = '';
        _speech.listen(
          onResult: (val) {
            setState(() {
              _lastWords = val.recognizedWords;
              _controller.text = _lastWords; // Live update text field
            });
          },
          localeId: 'zh_CN', // Force Chinese if available
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // --- TTS Logic ---
  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      // Filter out Markdown syntax roughly for better speech
      String cleanText = text
          .replaceAll(
              RegExp(r'[\#\*\-\`\[\]\(\)]'), '') // Remove common markdown chars
          .replaceAll(RegExp(r'http\S+'), ''); // Remove URLs

      setState(() => _isSpeaking = true);
      await _flutterTts.speak(cleanText);
    }
  }

  Future<void> _loadAiConfig() async {
    // Try cloud first, then local
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
            _apiKey = res['ai_api_key'];
            _baseUrl = res['ai_base_url'];
            _systemPrompt = res['ai_system_prompt'];
          });
          return;
        }
      } catch (e) {}
    }

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('ai_api_key');
      _baseUrl = prefs.getString('ai_base_url');
      _systemPrompt = prefs.getString('ai_system_prompt');
    });
  }

  Future<void> _initializeData() async {
    await _loadAiConfig();
    await _loadSessions();
    await _loadKnowledge(); // Load Knowledge
    if (_sessions.isEmpty) {
      _createNewSession();
    } else {
      _selectSession(_sessions.first.id);
    }
  }

  Future<void> _loadKnowledge() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('knowledge_base') ?? [];
    setState(() {
      _knowledgeEntries =
          list.map((e) => KnowledgeEntry.fromJson(jsonDecode(e))).toList();
    });
  }

  // --- Session Logic ---
  Future<void> _loadSessions() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final res = await Supabase.instance.client
          .from('chat_sessions')
          .select()
          .eq('user_id', uid)
          .order('last_updated_at', ascending: false);

      if (res != null) {
        setState(() {
          _sessions = (res as List)
              .map((e) => ChatSession.fromJson({
                    'id': e['id'],
                    'title': e['title'],
                    'createdAt': e['created_at'],
                    'lastUpdatedAt': e['last_updated_at'],
                  }))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Load sessions error: $e');
    }
  }

  // No longer saving sessions meta to shared prefs, relying on DB
  Future<void> _saveSessionsMeta() async {
    // Legacy: Keep empty or remove. DB handles persistence.
  }

  void _createNewSession() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final newId = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    try {
      await Supabase.instance.client.from('chat_sessions').insert({
        'id': newId,
        'user_id': uid,
        'title': '新对话',
        'created_at': now,
        'last_updated_at': now,
      });

      final newSession = ChatSession(
        id: newId,
        title: '新对话',
        createdAt: DateTime.parse(now),
        lastUpdatedAt: DateTime.parse(now),
      );

      setState(() {
        _sessions.insert(0, newSession);
        _currentSessionId = newId;
        _messages = [
          {
            'role': 'assistant',
            'content': '你好！我是你的 AI 健身教练。我可以帮你制定计划、解答健身疑问，或者估算食物热量。请问今天想练什么？'
          }
        ];
      });
      // Initial welcome message isn't usually saved to DB until user interacts,
      // or we can save it now. Let's save it now to be consistent.
      await _persistMessage(newId, 'assistant', _messages[0]['content']!);
    } catch (e) {
      debugPrint('Create session error: $e');
    }
  }

  void _selectSession(String sessionId) async {
    if (sessionId == _currentSessionId) return;

    setState(() {
      _currentSessionId = sessionId;
      _messages = []; // Clear current while loading
      _loading = true;
    });

    try {
      final res = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      setState(() {
        _messages = (res as List)
            .map((e) => {
                  'role': e['role'] as String,
                  'content': e['content'] as String,
                })
            .toList();
        _loading = false;
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Load messages error: $e');
      setState(() => _loading = false);
    }
  }

  void _deleteSession(String sessionId) async {
    try {
      await Supabase.instance.client
          .from('chat_sessions')
          .delete()
          .eq('id', sessionId);

      setState(() {
        _sessions.removeWhere((s) => s.id == sessionId);
        if (_currentSessionId == sessionId) {
          if (_sessions.isNotEmpty) {
            _selectSession(_sessions.first.id);
          } else {
            _createNewSession();
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  void _updateSessionTitleIfNeeded(String userText) async {
    final index = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (index != -1) {
      final session = _sessions[index];
      // Logic: Update title if it's default
      if (session.title == '新对话' || _messages.length <= 3) {
        final newTitle =
            userText.length > 15 ? '${userText.substring(0, 15)}...' : userText;
        setState(() {
          session.title = newTitle;
          session.lastUpdatedAt = DateTime.now();
        });

        await Supabase.instance.client.from('chat_sessions').update({
          'title': newTitle,
          'last_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentSessionId);
      } else {
        setState(() {
          session.lastUpdatedAt = DateTime.now();
        });
        await Supabase.instance.client.from('chat_sessions').update({
          'last_updated_at': DateTime.now().toIso8601String(),
        }).eq('id', _currentSessionId);
      }
    }
  }

  // New helper to persist single message
  Future<void> _persistMessage(
      String sessionId, String role, String content) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'session_id': sessionId,
        'user_id': uid,
        'role': role,
        'content': content,
      });
    } catch (e) {
      debugPrint('Persist message error: $e');
    }
  }

  // Deprecated local save
  Future<void> _saveMessages(String sessionId) async {
    // No-op, using _persistMessage instead
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
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, withData: true);
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

  Future<void> _callAiApiStream(String userContent) async {
    await _loadAiConfig();
    await _loadKnowledge(); // Reload knowledge to be fresh

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw '请先在右上角的设置中配置 API Key (如 DeepSeek)。';
    }

    final url = _baseUrl ?? 'https://api.deepseek.com/v1';
    final baseSystemPrompt = _systemPrompt ??
        'You are a helpful fitness coach. Please formatting your response with Markdown.';

    // --- Personalized Memory Logic ---
    String memoryContext = '';
    try {
      memoryContext = await MemoryService.getMemoryContext();
    } catch (e) {
      debugPrint('Memory load failed: $e');
    }
    // ---------------------------------

    // --- RAG Lite Logic ---
    String ragContext = '';
    List<String> usedTitles = [];

    for (var entry in _knowledgeEntries) {
      if (!entry.isActive) continue;
      bool match = false;
      // Match title
      if (userContent.contains(entry.title)) match = true;
      // Match keywords
      for (var kw in entry.keywords) {
        if (userContent.contains(kw)) {
          match = true;
          break;
        }
      }

      if (match) {
        ragContext += '\n\n【相关知识库: ${entry.title}】\n${entry.content}';
        usedTitles.add(entry.title);
      }
    }

    final finalSystemPrompt = '$baseSystemPrompt\n'
        '$memoryContext\n' // Inject Memory
        '${ragContext.isEmpty ? '' : '\n请优先参考以下私有知识库内容回答：$ragContext'}';

    // Notify UI if knowledge is used
    if (usedTitles.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📚 已引用知识库: ${usedTitles.join(", ")}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue.shade800,
        ),
      );
    }
    // ---------------------

    final List<Map<String, dynamic>> apiMessages = [
      {'role': 'system', 'content': finalSystemPrompt},
      ..._messages
          .take(10)
          .map((m) => {'role': m['role'], 'content': m['content']}),
    ];

    var apiUrl = Uri.parse('$url/chat/completions');
    if (kIsWeb) {
      if (url.contains('api.deepseek.com')) {
        final path = Uri.parse(url).path;
        apiUrl = Uri.parse('/api/deepseek$path/chat/completions');
      } else if (url.contains('api.openai.com')) {
        final path = Uri.parse(url).path;
        apiUrl = Uri.parse('/api/openai$path/chat/completions');
      }
    }

    final request = http.Request('POST', apiUrl);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    });
    request.body = jsonEncode({
      'model': 'deepseek-chat',
      'messages': apiMessages,
      'temperature': 0.7,
      'stream': true,
    });

    try {
      final streamedResponse = await request.send();
      if (streamedResponse.statusCode != 200) {
        throw 'API Error: ${streamedResponse.statusCode}';
      }

      setState(() {
        _messages.add({'role': 'assistant', 'content': ''});
      });

      String fullContent = '';

      await streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'] ?? '';
            fullContent += content;
            if (mounted) {
              setState(() {
                _messages.last['content'] = fullContent;
              });
              _scrollToBottom();
            }
          } catch (e) {}
        }
      }).asFuture();

      await _persistMessage(_currentSessionId, 'assistant', fullContent);
    } catch (e) {
      throw '连接 AI 失败: $e';
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _selectedImageBytes == null) return;

    String userContent = text;

    if (text.isNotEmpty) {
      _updateSessionTitleIfNeeded(text);
    }

    setState(() {
      _loading = true;
      if (_selectedImageBytes != null) {
        _messages.add({'role': 'user', 'content': '📷 [图片已上传] $text'});
      } else {
        _messages.add({'role': 'user', 'content': text});
      }
    });
    // _saveMessages(_currentSessionId);
    if (text.isNotEmpty) {
      await _persistMessage(_currentSessionId, 'user', text);
    } else if (_selectedImageBytes != null) {
      await _persistMessage(_currentSessionId, 'user', '📷 [图片已上传] $text');
    }

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
            // _saveMessages(_currentSessionId);
            await _persistMessage(
                _currentSessionId, 'assistant', '✅ 图片分析完成，正在结合视觉数据思考...');
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
        await _callAiApiStream(userContent);
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
          // _saveMessages(_currentSessionId);
          await _persistMessage(_currentSessionId, 'assistant', mockReply);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'role': 'assistant', 'content': '⚠️ $e'});
        });
        // _saveMessages(_currentSessionId);
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
      key: _scaffoldKey,
      drawer: ChatHistoryDrawer(
        sessions: _sessions,
        currentSessionId: _currentSessionId,
        onSessionSelected: _selectSession,
        onNewSession: _createNewSession,
        onDeleteSession: _deleteSession,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.history),
          tooltip: '历史对话',
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
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
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新对话',
            onPressed: _createNewSession,
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
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(
                bottom: 4), // Reduced margin for speaker icon
            constraints: const BoxConstraints(maxWidth: 320),
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
                extensionSet: md.ExtensionSet.gitHubFlavored,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : const Color(0xFF334155),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  code: TextStyle(
                    backgroundColor:
                        isUser ? Colors.black26 : Colors.grey.shade100,
                    color: isUser ? Colors.white : Colors.red,
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isUser ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  tableHead: TextStyle(
                    color: isUser ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                  tableBorder: TableBorder.all(
                    color: isUser ? Colors.white30 : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
          if (!isUser) // Only show speaker for AI messages
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _speak(content),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.volume_up, size: 16, color: Colors.grey),
                ),
              ),
            ),
        ],
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
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: _isListening ? '正在听...' : '问问 AI 教练...',
                        hintStyle: TextStyle(
                            color: _isListening ? Colors.red : Colors.grey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Voice Input Button
                GestureDetector(
                  onLongPressStart: (_) => _listen(),
                  onLongPressEnd: (_) => _listen(), // Stop listening on release
                  onTap: _listen, // Toggle for web maybe better
                  child: CircleAvatar(
                    backgroundColor:
                        _isListening ? Colors.red : Colors.grey.shade200,
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.white : Colors.black54),
                  ),
                ),
                const SizedBox(width: 8),
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
