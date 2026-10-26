import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_client.dart';
import '../models/story_model.dart';
import '../models/story_comment_model.dart';

class StoryService {
  // ─────────────────────────────────────────────
  // Singleton
  // ─────────────────────────────────────────────
  StoryService._();
  static final StoryService instance = StoryService._();

  static const _storiesTable  = 'stories';
  static const _likesTable    = 'story_likes';
  static const _commentsTable = 'story_comments';
  static const _storageBucket = 'stories';

  // ─────────────────────────────────────────────
  // Кардарлар үчүн: бардык активдүү stories'ти алуу
  // ─────────────────────────────────────────────
  Future<List<StoryModel>> fetchActiveStories() async {
    try {
      final List<Map<String, dynamic>> rows = await supabase
          .from(_storiesTable)
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final userId = supabase.auth.currentUser?.id;
      List<String> likedIds = [];

      if (userId != null) {
        final List<Map<String, dynamic>> likes = await supabase
            .from(_likesTable)
            .select('story_id')
            .eq('user_id', userId);
        likedIds = likes.map((e) => e['story_id'] as String).toList();
      }

      return rows.map((row) {
        final story = StoryModel.fromMap(row);
        return story.copyWith(isLikedByMe: likedIds.contains(story.id));
      }).toList();
    } catch (e) {
      debugPrint('❌ StoryService.fetchActiveStories: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // Админ үчүн: баарын алуу (is_active = false дагы)
  // ─────────────────────────────────────────────
  Future<List<StoryModel>> fetchAllStories() async {
    try {
      final List<Map<String, dynamic>> rows = await supabase
          .from(_storiesTable)
          .select()
          .order('created_at', ascending: false);

      return rows.map((row) => StoryModel.fromMap(row)).toList();
    } catch (e) {
      debugPrint('❌ StoryService.fetchAllStories: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // Админ: сүрөт же видео жүктөп, story кошуу
  // ─────────────────────────────────────────────
  Future<StoryModel?> uploadAndCreateStory({
    required Uint8List bytes, // веб + мобилге бирдей (File эмес)
    required String mediaType, // 'image' же 'video'
  }) async {
    try {
      // ── Файл форматы жана Content-Type аныктоо ──
      final ext         = mediaType == 'video' ? 'mp4' : 'jpg';
      final contentType = mediaType == 'video' ? 'video/mp4' : 'image/jpeg';
      final fileName    = '${DateTime.now().millisecondsSinceEpoch}.$ext';

      // ── 1. Supabase Storage'га туура contentType менен жүктөө ──
      await supabase.storage
          .from(_storageBucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType, // ✅ НЕГИЗГИ ОҢДОО
              upsert: false,
            ),
          );

      // ── 2. Публичный URL алуу ──
      final mediaUrl = supabase.storage
          .from(_storageBucket)
          .getPublicUrl(fileName);

      // ── 3. Базага жазуу ──
      final Map<String, dynamic> row = await supabase
          .from(_storiesTable)
          .insert({
            'media_url':   mediaUrl,
            'media_type':  mediaType,
            'is_active':   true,
            'likes_count': 0,
          })
          .select()
          .single();

      return StoryModel.fromMap(row);
    } catch (e) {
      debugPrint('❌ StoryService.uploadAndCreateStory: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // Админ: story'ни жашыруу (is_active = false)
  // ─────────────────────────────────────────────
  Future<bool> deactivateStory(String storyId) async {
    try {
      await supabase
          .from(_storiesTable)
          .update({'is_active': false})
          .eq('id', storyId);
      return true;
    } catch (e) {
      debugPrint('❌ StoryService.deactivateStory: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Админ: story'ни кайра активдештирүү
  // ─────────────────────────────────────────────
  Future<bool> activateStory(String storyId) async {
    try {
      await supabase
          .from(_storiesTable)
          .update({'is_active': true})
          .eq('id', storyId);
      return true;
    } catch (e) {
      debugPrint('❌ StoryService.activateStory: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Админ: story'ни толугу менен жок кылуу
  // ─────────────────────────────────────────────
  Future<bool> deleteStory(String storyId) async {
    try {
      // 1. Storage'дан файлды жок кылуу (URL'дан файл атын алуу)
      try {
        final row = await supabase
            .from(_storiesTable)
            .select('media_url')
            .eq('id', storyId)
            .maybeSingle();

        if (row != null) {
          final url      = row['media_url'] as String? ?? '';
          final fileName = Uri.parse(url).pathSegments.last;
          if (fileName.isNotEmpty) {
            await supabase.storage
                .from(_storageBucket)
                .remove([fileName]);
          }
        }
      } catch (storageErr) {
        // Storage'дан өчүрүү ката берсе — DB'дан дагы өчүрөбүз
        debugPrint('⚠️ Storage delete error (ignored): $storageErr');
      }

      // 2. DB'дан жок кылуу
      await supabase
          .from(_storiesTable)
          .delete()
          .eq('id', storyId);

      return true;
    } catch (e) {
      debugPrint('❌ StoryService.deleteStory: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Кардар: лайк кошуу / алып салуу (toggle)
  // ─────────────────────────────────────────────
  Future<({bool liked, int newCount})> toggleLike(StoryModel story) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return (liked: story.isLikedByMe, newCount: story.likesCount);
    }

    try {
      if (story.isLikedByMe) {
        // ── Лайкты алып салуу ──
        await supabase
            .from(_likesTable)
            .delete()
            .eq('story_id', story.id)
            .eq('user_id', userId);

        final newCount = (story.likesCount - 1).clamp(0, 999999);
        await supabase
            .from(_storiesTable)
            .update({'likes_count': newCount})
            .eq('id', story.id);

        return (liked: false, newCount: newCount);
      } else {
        // ── Лайк кошуу ──
        await supabase.from(_likesTable).insert({
          'story_id': story.id,
          'user_id':  userId,
        });

        final newCount = story.likesCount + 1;
        await supabase
            .from(_storiesTable)
            .update({'likes_count': newCount})
            .eq('id', story.id);

        return (liked: true, newCount: newCount);
      }
    } catch (e) {
      debugPrint('❌ StoryService.toggleLike: $e');
      return (liked: story.isLikedByMe, newCount: story.likesCount);
    }
  }

  // ─────────────────────────────────────────────
  // Комментарийлер
  // ─────────────────────────────────────────────
  Future<List<StoryCommentModel>> fetchComments(String storyId) async {
    try {
      final List<Map<String, dynamic>> rows = await supabase
          .from(_commentsTable)
          .select()
          .eq('story_id', storyId)
          .order('created_at', ascending: false);
      return rows.map(StoryCommentModel.fromMap).toList();
    } catch (e) {
      debugPrint('❌ StoryService.fetchComments: $e');
      return [];
    }
  }

  Future<int> commentsCount(String storyId) async {
    try {
      final rows = await supabase
          .from(_commentsTable)
          .select('id')
          .eq('story_id', storyId);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<StoryCommentModel?> addComment(String storyId, String text) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      String name = 'Колдонуучу';
      String? avatar;
      try {
        final prof = await supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        name = (prof?['full_name'] as String?) ?? user.email?.split('@').first ?? name;
        avatar = prof?['avatar_url'] as String?;
      } catch (_) {}

      final row = await supabase
          .from(_commentsTable)
          .insert({
            'story_id': storyId,
            'user_id': user.id,
            'user_name': name,
            'avatar_url': avatar,
            'text': text.trim(),
          })
          .select()
          .single();
      return StoryCommentModel.fromMap(row);
    } catch (e) {
      debugPrint('❌ StoryService.addComment: $e');
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await supabase.from(_commentsTable).delete().eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('❌ StoryService.deleteComment: $e');
      return false;
    }
  }
}
