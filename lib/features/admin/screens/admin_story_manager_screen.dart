import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/utils/image_utils.dart'; // ← compressStoryImage үчүн
import '../../stories/models/story_model.dart';
import '../../stories/services/story_service.dart';
import '../widgets/admin_story_card.dart';

class AdminStoryManagerScreen extends StatefulWidget {
  const AdminStoryManagerScreen({super.key});

  @override
  State<AdminStoryManagerScreen> createState() =>
      _AdminStoryManagerScreenState();
}

class _AdminStoryManagerScreenState extends State<AdminStoryManagerScreen> {
  final _service = StoryService.instance;
  final _picker  = ImagePicker();

  List<StoryModel> _stories = [];
  bool _isLoading     = true;
  bool _isUploading   = false;
  String _uploadStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ─────────────────────────────────────────────
  // Маалыматтарды жүктөө
  // ─────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _service.fetchAllStories();
    if (mounted) setState(() { _stories = list; _isLoading = false; });
  }

  // ─────────────────────────────────────────────
  // Медиа тандоо жана жүктөө
  // ─────────────────────────────────────────────
  Future<void> _pickAndUpload(ImageSource source, String mediaType) async {
    try {
      XFile? picked;

      if (mediaType == 'image') {
        // imageQuality жана maxWidth алынды — compressStoryImage өзү башкарат
        picked = await _picker.pickImage(source: source);
      } else {
        picked = await _picker.pickVideo(source: source);
      }

      if (picked == null) return;

      setState(() {
        _isUploading  = true;
        _uploadStatus = 'Жүктөлүп жатат...';
      });

      File file;

      if (mediaType == 'image') {
        // ── Сүрөттү оригинал катышта compress кылуу ──
        final bytes      = await picked.readAsBytes();
        final compressed = await compressStoryImage(bytes); // ← ОШУ ЖЕР

        // Убактылуу файлга жазуу
        final tempPath = '${picked.path}_story.jpg';
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(compressed);
        file = tempFile;
      } else {
        // Видеону түздөн-түз берүү — катыш өзүнөн сакталат
        file = File(picked.path);
      }

      final story = await _service.uploadAndCreateStory(
        file:      file,
        mediaType: mediaType,
      );

      if (story != null) {
        setState(() {
          _stories.insert(0, story);
          _uploadStatus = '✅ Ийгиликтүү жүктөлдү!';
        });
        await Future.delayed(const Duration(seconds: 2));
      } else {
        setState(() => _uploadStatus = '❌ Жүктөөдө ката чыкты');
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      setState(() => _uploadStatus = '❌ Ката: $e');
      await Future.delayed(const Duration(seconds: 2));
    } finally {
      if (mounted) setState(() { _isUploading = false; _uploadStatus = ''; });
    }
  }

  // ─────────────────────────────────────────────
  // Активдештирүү / өчүрүү
  // ─────────────────────────────────────────────
  Future<void> _toggleActive(StoryModel story) async {
    final ok = story.isActive
        ? await _service.deactivateStory(story.id)
        : await _service.activateStory(story.id);

    if (ok && mounted) {
      setState(() {
        final idx = _stories.indexWhere((s) => s.id == story.id);
        if (idx != -1) {
          _stories[idx] = story.copyWith(isActive: !story.isActive);
        }
      });
    }
  }

  // ─────────────────────────────────────────────
  // Жок кылуу (confirm менен)
  // ─────────────────────────────────────────────
  Future<void> _delete(StoryModel story) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('🗑️ Жаңылыкты өчүрүү'),
        content: const Text('Бул жаңылык толугу менен жок болот.\nУлантасызбы?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ооба, өчүр'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _service.deleteStory(story.id);
    if (ok && mounted) {
      setState(() => _stories.removeWhere((s) => s.id == story.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Жаңылык өчүрүлдү'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Жүктөө баракчасы (BottomSheet)
  // ─────────────────────────────────────────────
  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Сызык
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Жаңылык кошуу', style: AppTextStyles.headingSmall),
            const SizedBox(height: 6),
            Text(
              'Сүрөт же видео тандаңыз. Жаңылык сиз өчүрмөйүнчө туруп калат.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey500),
            ),
            const SizedBox(height: 24),

            // ── 4 кнопка ──
            _uploadOption(
              icon: Icons.photo_library_outlined,
              label: '📷 Галереядан сүрөт',
              color: AppColors.info,
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery, 'image');
              },
            ),
            const SizedBox(height: 10),
            _uploadOption(
              icon: Icons.camera_alt_outlined,
              label: '📸 Камерадан тартуу',
              color: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera, 'image');
              },
            ),
            const SizedBox(height: 10),
            _uploadOption(
              icon: Icons.video_library_outlined,
              label: '🎬 Галереядан видео',
              color: AppColors.secondary,
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.gallery, 'video');
              },
            ),
            const SizedBox(height: 10),
            _uploadOption(
              icon: Icons.videocam_outlined,
              label: '🎥 Камерадан видео тартуу',
              color: AppColors.success,
              onTap: () {
                Navigator.pop(context);
                _pickAndUpload(ImageSource.camera, 'video');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(label,
                style: AppTextStyles.bodyMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);

    final activeCount   = _stories.where((s) => s.isActive).length;
    final inactiveCount = _stories.length - activeCount;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.black,
        elevation: 0,
        title: const Text('📢 Жаңылыктар', style: AppTextStyles.headingSmall),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Жаңыртуу',
          ),
        ],
      ),

      // ── FAB — жаңылык кошуу ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _showUploadSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _isUploading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add),
        label: Text(
          _isUploading ? _uploadStatus : 'Жаңылык кошуу',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // ── Статистика ──
                Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      _statChip(
                          label: 'Баары',
                          count: _stories.length,
                          color: AppColors.info),
                      const SizedBox(width: 10),
                      _statChip(
                          label: 'Активдүү',
                          count: activeCount,
                          color: AppColors.success),
                      const SizedBox(width: 10),
                      _statChip(
                          label: 'Өчүк',
                          count: inactiveCount,
                          color: AppColors.grey400),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── Тизме ──
                Expanded(
                  child: _stories.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _stories.length,
                            itemBuilder: (_, i) => AdminStoryCard(
                              story:          _stories[i],
                              onToggleActive: () => _toggleActive(_stories[i]),
                              onDelete:       () => _delete(_stories[i]),
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📭', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Азырынча жаңылык жок',
              style: AppTextStyles.headingSmall
                  .copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Text('Төмөндөгү + баскычты басып кошуңуз',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.grey400)),
        ],
      ),
    );
  }
}