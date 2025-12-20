import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

// 数据模型：会话
class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastUpdatedAt;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'],
        title: json['title'],
        createdAt: DateTime.parse(json['createdAt']),
        lastUpdatedAt: DateTime.parse(json['lastUpdatedAt']),
      );
}

// 侧边栏抽屉：历史会话列表
class ChatHistoryDrawer extends StatelessWidget {
  final List<ChatSession> sessions;
  final String currentSessionId;
  final Function(String) onSessionSelected;
  final VoidCallback onNewSession;
  final Function(String) onDeleteSession;

  const ChatHistoryDrawer({
    super.key,
    required this.sessions,
    required this.currentSessionId,
    required this.onSessionSelected,
    required this.onNewSession,
    required this.onDeleteSession,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text('AI 健身私教'),
            accountEmail: const Text('您的私人智能助手'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.fitness_center, color: Colors.blue),
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close drawer
                  onNewSession();
                },
                icon: const Icon(Icons.add),
                label: const Text('开启新对话'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: sessions.isEmpty
                ? const Center(
                    child: Text('暂无历史记录', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isSelected = session.id == currentSessionId;
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, size: 20),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? const Color(0xFF2563EB) : null,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('MM-dd HH:mm').format(session.lastUpdatedAt),
                          style: const TextStyle(fontSize: 10),
                        ),
                        selected: isSelected,
                        selectedTileColor: Colors.blue.withOpacity(0.05),
                        onTap: () {
                          Navigator.pop(context);
                          onSessionSelected(session.id);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          onPressed: () => onDeleteSession(session.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
