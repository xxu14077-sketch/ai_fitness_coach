import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ai_fitness_coach/ui/theme.dart';
import 'package:uuid/uuid.dart';

class KnowledgeEntry {
  final String id;
  String title;
  String content;
  List<String> keywords;
  bool isActive;

  KnowledgeEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.keywords,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'keywords': keywords,
        'is_active': isActive,
      };

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) => KnowledgeEntry(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        keywords: List<String>.from(json['keywords'] ?? []),
        isActive: json['is_active'] ?? true,
      );
}

class KnowledgeBasePage extends StatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  State<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends State<KnowledgeBasePage> {
  List<KnowledgeEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('knowledge_base')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      setState(() {
        _entries =
            (res as List).map((e) => KnowledgeEntry.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load knowledge error: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _addOrUpdateEntry(KnowledgeEntry entry, bool isNew) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await Supabase.instance.client.from('knowledge_base').upsert({
        'id': entry.id,
        'user_id': uid,
        'title': entry.title,
        'content': entry.content,
        'keywords': entry.keywords,
        'is_active': entry.isActive,
      });
      await _loadEntries();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await Supabase.instance.client
          .from('knowledge_base')
          .delete()
          .eq('id', id);
      setState(() {
        _entries.removeWhere((e) => e.id == id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  void _showEntryDialog([KnowledgeEntry? entry]) {
    final titleCtrl = TextEditingController(text: entry?.title);
    final contentCtrl = TextEditingController(text: entry?.content);
    final keywordsCtrl =
        TextEditingController(text: entry?.keywords.join(', '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry == null ? '添加知识库' : '编辑知识库'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: '标题 (如: 生酮饮食法)',
                  hintText: '简短的主题名称',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keywordsCtrl,
                decoration: const InputDecoration(
                  labelText: '触发关键词 (逗号分隔)',
                  hintText: '生酮, 低碳, 脂肪',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '知识内容',
                  hintText: 'AI 在回答相关问题时将参考这段内容...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleCtrl.text.trim();
              final content = contentCtrl.text.trim();
              if (title.isEmpty || content.isEmpty) return;

              final keywords = keywordsCtrl.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              if (keywords.isEmpty) keywords.add(title);

              final newEntry = KnowledgeEntry(
                id: entry?.id ?? const Uuid().v4(),
                title: title,
                content: content,
                keywords: keywords,
                isActive: entry?.isActive ?? true,
              );

              _addOrUpdateEntry(newEntry, entry == null);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('私有知识库 (RAG Lite)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEntryDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        '知识库为空\n点击右上角添加您的专属健身知识',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '关键词: ${entry.keywords.join(", ")}\n内容预览: ${entry.content.length > 30 ? "${entry.content.substring(0, 30)}..." : entry.content}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Switch(
                          value: entry.isActive,
                          onChanged: (val) {
                            setState(() {
                              entry.isActive = val;
                            });
                            _addOrUpdateEntry(entry, false);
                          },
                        ),
                        onTap: () => _showEntryDialog(entry),
                        onLongPress: () => showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('删除此条目？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _deleteEntry(entry.id);
                                  Navigator.pop(ctx);
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
