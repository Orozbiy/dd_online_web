import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../core/supabase_client.dart';
import '../models/story_model.dart';

class StoryService {
  // ─────────────────────────────────────────────
  // Singleton
  // ─────────────────────────────────────────────
  StoryService._();
  static final StoryService instance = StoryService._();

  static const _storiesTable   = 'stories';
  static const _likesTable     = 'story_likes';
  static const _storageBucket  = 'stories';

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
    required File file,
    required String mediaType, // 'image' же 'video'
  }) async {
    try {
      // 1. Файлды Storage'га жүктөө
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

      await supabase.storage
          .from(_storageBucket)
          .upload(fileName, file);

      final mediaUrl = supabase.storage
          .from(_storageBucket)
          .getPublicUrl(fileName);

      // 2. DB'га жазуу
      final Map<String, dynamic> row = await supabase
          .from(_storiesTable)
          .insert({
            'media_url':  mediaUrl,
            'media_type': mediaType,
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
  // Админ: story'ни өчүрүү (is_active = false)
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

  // Кайра активдештирүү
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

  // Толугу менен жок кылуу
  Future<bool> deleteStory(String storyId) async {
    try {
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
    if (userId == null) return (liked: story.isLikedByMe, newCount: story.likesCount);

    try {
      if (story.isLikedByMe) {
        // Лайкты алып салуу
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
        // Лайк кошуу
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
}
