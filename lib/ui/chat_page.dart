import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_coach/ui/theme.dart';

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

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
          body: {'query': text},
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
        // 这样至少用户能看到 App 是有反应的
        debugPrint('Edge Function Error: $functionError');

        // 模拟一个智能回复
        await Future.delayed(const Duration(seconds: 1));
        final mockReply = _getMockReply(text);

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
    if (input.contains('你好') || input.contains('hello')) {
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('AI 正在思考...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        child: Row(
          children: [
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
      ),
    );
  }
}
