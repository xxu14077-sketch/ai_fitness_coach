import 'package:flutter/material.dart';
import 'package:ai_fitness_coach/core/community_service.dart';
import 'package:ai_fitness_coach/ui/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final CommunityService _service = CommunityService();
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await _service.getPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showComposeDialog() {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('分享你的训练成就'),
        content: TextField(
          controller: textCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '今天练得怎么样？感觉如何？',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (textCtrl.text.trim().isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('正在发布...')),
                );
                await _service.createPost(textCtrl.text.trim());
                await _fetchPosts(); // Refresh
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('发布成功！AI 教练正在赶来评论...')),
                  );
                  // Refresh again after delay to show AI comment
                  Future.delayed(const Duration(seconds: 3), _fetchPosts);
                }
              }
            },
            child: const Text('发布'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健身社区'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPosts,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPosts,
              child: _posts.isEmpty
                  ? const Center(child: Text('还没人发帖，快来抢沙发！'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        return _PostCard(
                          post: _posts[index],
                          onLike: () async {
                            await _service.toggleLike(_posts[index]['id']);
                            _fetchPosts();
                          },
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComposeDialog,
        icon: const Icon(Icons.edit),
        label: const Text('分享'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;

  const _PostCard({required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final comments = (post['comments'] as List?) ?? [];
    final likesCount = post['likes_count'] ?? 0;
    final content = post['content'] ?? '';
    final date = DateTime.parse(post['created_at']).toLocal().toString().substring(0, 16);
    
    // Check if current user liked
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final likes = (post['likes'] as List?) ?? [];
    final isLiked = likes.any((l) => l['user_id'] == uid);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('健身伙伴', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(fontSize: 16)),
            const Divider(height: 24),
            Row(
              children: [
                InkWell(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text('$likesCount'),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                const Icon(Icons.comment_outlined, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${comments.length}'),
              ],
            ),
            if (comments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: comments.map((c) {
                    final isAi = c['username'] == 'AI 教练';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 13),
                          children: [
                            TextSpan(
                              text: '${c['username']}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAi ? AppTheme.primaryColor : Colors.black87,
                              ),
                            ),
                            TextSpan(text: c['content']),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
