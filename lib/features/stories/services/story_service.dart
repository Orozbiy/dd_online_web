import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/supabase_client.dart';
import '../models/story_model.dart';

class StoryService {
  // ─────────────────────────────────────────────
  // Singleton
  // ─────────────────────────────────────────────
  StoryService._();
  static final StoryService instance = StoryService._();

  static const _storiesTable  = 'stories';
  static const _likesTable    = 'story_likes';

  // ── Cloudinary маалыматтары ──
  static const _cloudName    = 'dedwm4krp';
  static const _uploadPreset = 'dd-online';

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
    required String mediaType,
  }) async {
    try {
      // 1. Cloudinary'га жүктөө
      final mediaUrl = await _uploadToCloudinary(file, mediaType);
      if (mediaUrl == null) return null;

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
  // Cloudinary'га жүктөө (сүрөт же видео)
  // ─────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file, String mediaType) async {
    try {
      final endpoint = mediaType == 'video' ? 'video' : 'image';
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$endpoint/upload',
      );

      final ext = file.path.contains('.')
          ? '.${file.path.split('.').last}'
          : '';
      final filename =
          '${mediaType}_${DateTime.now().millisecondsSinceEpoch}$ext';

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: filename,
        ));

      final streamed = await request.send().timeout(
        const Duration(minutes: 3),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }
      debugPrint(
          '❌ Cloudinary ката: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ _uploadToCloudinary: $e');
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
    if (userId == null) {
      return (liked: story.isLikedByMe, newCount: story.likesCount);
    }

    try {
      if (story.isLikedByMe) {
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
