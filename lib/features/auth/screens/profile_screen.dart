import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/app_localizations.dart';
import '../../../core/auth_service.dart';
import '../../../core/supabase_client.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading        = true;
  bool _isSaving         = false;
  bool _isUploadingPhoto = false;

  String  _fullName  = '';
  String  _email     = '';
  String  _phone     = '';
  String? _avatarUrl;

  final _fullNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final data = await supabase.from('profiles').select().eq('id', user.id).single();
      if (mounted) {
        setState(() {
          _fullName  = data['full_name']  as String? ?? '';
          _email     = data['email']      as String? ?? user.email ?? '';
          _phone     = data['phone']      as String? ?? '';
          _avatarUrl = data['avatar_url'] as String?;
          _fullNameController.text = _fullName;
        });
      }
    } catch (e) {
      debugPrint('_loadUser error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final loc    = AppLocalizations.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 512);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final file        = File(picked.path);
      final storagePath = 'avatars/${user.id}.jpg';
      await supabase.storage.from('product-images').upload(storagePath, file, fileOptions: const FileOptions(upsert: true));
      final url = supabase.storage.from('product-images').getPublicUrl(storagePath);
      await supabase.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      setState(() => _avatarUrl = url);
      if (mounted) _showSnack(loc.get('profile_photo_updated'), success: true);
    } catch (e) {
      if (mounted) _showSnack('${AppLocalizations.of(context).get('error')}: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    final loc      = AppLocalizations.of(context);
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      _showSnack(loc.get('profile_name_required'));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      await supabase.from('profiles').update({'full_name': fullName}).eq('id', user.id);
      setState(() => _fullName = fullName);
      if (mounted) {
        _showSnack(loc.get('profile_saved'), success: true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('${AppLocalizations.of(context).get('error')}: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditSheet() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(loc.get('profile_edit_title'), style: AppTextStyles.headingMedium),
            const SizedBox(height: 20),
            Text(loc.get('profile_label_name'), style: AppTextStyles.bodySmall),
            const SizedBox(height: 6),
            TextField(
              controller: _fullNameController,
              style: AppTextStyles.labelLarge,
              decoration: InputDecoration(
                hintText: loc.get('profile_hint_name'),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : AppColors.grey50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(loc.get('save'), style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _signOut() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.get('sign_out'), style: AppTextStyles.headingSmall),
        content: Text(loc.get('profile_signout_confirm'), style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.get('no'), style: const TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () async {
              await AuthService.instance.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
              }
            },
            child: Text(loc.get('yes'), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final dividerColor = isDark ? const Color(0xFF2C2C2C) : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
        ),
        title: Text(loc.get('profile'), style: AppTextStyles.headingMedium),
        actions: [
          IconButton(
            onPressed: _showEditSheet,
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // ── АВАТАР ──
                  Center(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: _avatarUrl == null
                                  ? const LinearGradient(colors: [Color(0xFFD97706), Color(0xFFEF4444)])
                                  : null,
                              image: _avatarUrl != null
                                  ? DecorationImage(image: NetworkImage(_avatarUrl!), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: _avatarUrl == null
                                ? Center(
                                    child: Text(
                                      _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?',
                                      style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: cardColor, width: 2),
                              ),
                              child: _isUploadingPhoto
                                  ? const Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  Text(
                    _fullName.trim().isEmpty ? loc.get('profile_no_name') : _fullName.trim(),
                    style: AppTextStyles.headingMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email.isNotEmpty ? _email : '—',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey500),
                  ),

                  const SizedBox(height: 28),

                  // ── МААЛЫМАТТАР ──
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        _profileItem(Icons.person_outline, loc.get('profile_label_name'), _fullName),
                        Divider(height: 1, indent: 54, color: dividerColor),
                        _profileItem(Icons.email_outlined, 'Email', _email),
                        Divider(height: 1, indent: 54, color: dividerColor),
                        _profileItem(Icons.phone_outlined, loc.get('profile_label_phone'), _phone),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── ЧЫГУУ ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: _signOut,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.error.withValues(alpha: 0.15)
                              : const Color(0xFFFFEEEE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(
                              loc.get('profile_signout_btn'),
                              style: AppTextStyles.headingSmall.copyWith(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _profileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              Text(value.isNotEmpty ? value : '—', style: AppTextStyles.labelLarge),
            ],
          ),
        ],
      ),
    );
  }
}