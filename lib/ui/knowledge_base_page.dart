import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        'isActive': isActive,
      };

  factory KnowledgeEntry.fromJson(Map<String, dynamic> json) => KnowledgeEntry(
        id: json['id'],
        title: json['title'],
        content: json['content'],
        keywords: List<String>.from(json['keywords'] ?? []),
        isActive: json['isActive'] ?? true,
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
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('knowledge_base') ?? [];
    setState(() {
      _entries = list.map((e) => KnowledgeEntry.fromJson(jsonDecode(e))).toList();
      _loading = false;
    });
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _entries.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('knowledge_base', list);
  }

  void _addOrEditEntry([KnowledgeEntry? entry]) {
    final titleCtrl = TextEditingController(text: entry?.title);
    final contentCtrl = TextEditingController(text: entry?.content);
    final keywordsCtrl = TextEditingController(text: entry?.keywords.join(', '));

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
              
              // If no keywords, use title as keyword
              if (keywords.isEmpty) keywords.add(title);

              setState(() {
                if (entry != null) {
                  entry.title = title;
                  entry.content = content;
                  entry.keywords = keywords;
                } else {
                  _entries.add(KnowledgeEntry(
                    id: const Uuid().v4(),
                    title: title,
                    content: content,
                    keywords: keywords,
                  ));
                }
              });
              _saveEntries();
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _deleteEntry(String id) {
    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
    _saveEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('私有知识库 (RAG Lite)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addOrEditEntry(),
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
                            _saveEntries();
                          },
                        ),
                        onTap: () => _addOrEditEntry(entry),
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
