import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // Fetch Posts
  Future<List<Map<String, dynamic>>> getPosts() async {
    final res = await _client
        .from('posts')
        .select('*, comments(*), likes(*)') // Join comments and likes
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res as List);
  }

  // Create Post
  Future<void> createPost(String content) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    // 1. Insert Post
    final res = await _client
        .from('posts')
        .insert({
          'user_id': uid,
          'content': content,
        })
        .select()
        .single();

    // 2. Trigger AI Comment (Async)
    _triggerAiEncouragement(res['id'], content);
  }

  // Toggle Like
  Future<void> toggleLike(String postId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      // Check if liked
      final existing = await _client
          .from('likes')
          .select()
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _client
            .from('likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
        _rpcIncrementLikes(postId, -1);
      } else {
        // Like
        await _client.from('likes').insert({
          'post_id': postId,
          'user_id': uid,
        });
        _rpcIncrementLikes(postId, 1);
      }
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  // Add Comment
  Future<void> addComment(String postId, String content,
      {String? username, bool isAi = false}) async {
    final uid = _client.auth.currentUser?.id;
    // Note: For AI comments, uid might be null or special
    await _client.from('comments').insert({
      'post_id': postId,
      'user_id': isAi ? null : uid,
      'username': username ?? (isAi ? 'AI 教练' : '健身同伴'),
      'content': content,
    });
  }

  // AI Magic: Generate encouraging comment
  Future<void> _triggerAiEncouragement(String postId, String postContent) async {
    // Simulate thinking delay
    await Future.delayed(const Duration(seconds: 2));

    final encouragingPhrases = [
      "太棒了！坚持就是胜利！💪",
      "这种自律的精神值得学习！保持状态！🔥",
      "今天也是元气满满的一天呢！加油！✨",
      "看这数据，进步很明显啊！继续冲！🚀",
      "休息也是训练的一部分，别忘了拉伸哦~ 🧘‍♂️",
      "这就是强者的世界吗？我也要加油了！🤖",
    ];

    // Simple keyword matching for better context
    String reply = encouragingPhrases[Random().nextInt(encouragingPhrases.length)];
    
    if (postContent.contains("累") || postContent.contains("力竭")) {
      reply = "力竭是变强的前兆！好好休息，补充蛋白质！🥩";
    } else if (postContent.contains("开心") || postContent.contains("爽")) {
      reply = "享受多巴胺的分泌吧！这感觉太棒了！😄";
    } else if (postContent.contains("早")) {
      reply = "早起的鸟儿有虫吃，早起的健人有肌练！🌞";
    }

    await addComment(postId, reply, isAi: true);
  }

  // Helper to update like count (Optimistic or RPC)
  Future<void> _rpcIncrementLikes(String postId, int amount) async {
    // Since we don't have RPC easily, we fetch and update (not atomic but okay for demo)
    final res = await _client.from('posts').select('likes_count').eq('id', postId).single();
    int current = res['likes_count'] ?? 0;
    await _client.from('posts').update({'likes_count': current + amount}).eq('id', postId);
  }
}
