import 'dart:typed_data';
import 'dart:ui';
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
  bool    _isSeller  = false;

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
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      if (mounted) {
        final rawEmail       = data['email'] as String? ?? user.email ?? '';
        final isSellerEmail  = rawEmail.endsWith('@dd-online-seller.local');
        setState(() {
          _fullName  = data['full_name']  as String? ?? '';
          _email     = isSellerEmail ? '' : rawEmail;
          _isSeller  = isSellerEmail;
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
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 70, maxWidth: 512);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      // Веб + мобил: File эмес, байттар менен жүктөйбүз
      final Uint8List bytes = await picked.readAsBytes();
      final storagePath = 'avatars/${user.id}.jpg';
      await supabase.storage.from('product-images').uploadBinary(
            storagePath, bytes,
            fileOptions: const FileOptions(
                upsert: true, contentType: 'image/jpeg'));
      final url =
          supabase.storage.from('product-images').getPublicUrl(storagePath);
      await supabase
          .from('profiles')
          .update({'avatar_url': url}).eq('id', user.id);
      setState(() => _avatarUrl = url);
      if (mounted) _showSnack(loc.get('profile_photo_updated'), success: true);
    } catch (e) {
      if (mounted)
        _showSnack('${AppLocalizations.of(context).get('error')}: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deleteAvatar() async {
    final loc = AppLocalizations.of(context);
    setState(() => _isUploadingPhoto = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final storagePath = 'avatars/${user.id}.jpg';
      try {
        await supabase.storage.from('product-images').remove([storagePath]);
      } catch (e) {
        debugPrint('_deleteAvatar storage remove error: $e');
      }
      await supabase
          .from('profiles')
          .update({'avatar_url': null}).eq('id', user.id);
      setState(() => _avatarUrl = null);
      if (mounted) _showSnack(loc.get('profile_photo_deleted'), success: true);
    } catch (e) {
      if (mounted)
        _showSnack('${AppLocalizations.of(context).get('error')}: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _onAvatarTap() {
    if (_avatarUrl == null) {
      _pickAndUploadAvatar();
      return;
    }
    _showAvatarOptionsSheet();
  }

  void _showAvatarOptionsSheet() {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.9),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 12, 12, MediaQuery.of(context).padding.bottom + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.grey300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.primary),
                  title: Text(loc.get('profile_change_photo'),
                      style: AppTextStyles.labelLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.black)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: AppColors.error),
                  title: Text(loc.get('profile_delete_photo'),
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteAvatar();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAvatar() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.80),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.9),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.get('profile_delete_photo'),
                      style: AppTextStyles.headingSmall),
                  const SizedBox(height: 10),
                  Text(loc.get('profile_delete_photo_confirm'),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.grey500)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.grey300, width: 1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(loc.get('no'),
                              style: const TextStyle(
                                  color: AppColors.grey500)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _deleteAvatar();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.error.withOpacity(0.15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(loc.get('yes'),
                              style: const TextStyle(
                                  color: AppColors.error)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      await supabase
          .from('profiles')
          .update({'full_name': fullName}).eq('id', user.id);
      setState(() => _fullName = fullName);
      if (mounted) {
        _showSnack(loc.get('profile_saved'), success: true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted)
        _showSnack('${AppLocalizations.of(context).get('error')}: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showEditSheet() {
    final loc    = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.75),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.9),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 20, 20,
                MediaQuery.of(context).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : AppColors.grey300,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(loc.get('profile_edit_title'),
                    style: AppTextStyles.headingMedium.copyWith(
                        color: isDark ? Colors.white : AppColors.black)),
                const SizedBox(height: 20),
                Text(loc.get('profile_label_name'),
                    style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? Colors.white70
                            : AppColors.grey500)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: TextField(
                      controller: _fullNameController,
                      style: AppTextStyles.labelLarge.copyWith(
                          color: isDark ? Colors.white : AppColors.black),
                      decoration: InputDecoration(
                        hintText: loc.get('profile_hint_name'),
                        hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : AppColors.grey400),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.6),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(loc.get('save'),
                            style: AppTextStyles.labelLarge
                                .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
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
        backgroundColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.80),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.9),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.get('sign_out'),
                      style: AppTextStyles.headingSmall),
                  const SizedBox(height: 10),
                  Text(loc.get('profile_signout_confirm'),
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.grey500)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.grey300, width: 1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(loc.get('no'),
                              style: const TextStyle(
                                  color: AppColors.grey500)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await AuthService.instance.signOut();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const WelcomeScreen()),
                                  (route) => false);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                AppColors.error.withOpacity(0.15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(loc.get('yes'),
                              style: const TextStyle(
                                  color: AppColors.error)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // GLASS CARD HELPER
  // ════════════════════════════════════════════════
  Widget _glassCard({required bool isDark, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : Colors.white.withOpacity(0.80),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loc      = AppLocalizations.of(context);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.black;
    final subColor  = isDark ? const Color(0xFFAAAAAA) : AppColors.grey500;
    final divColor  = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE);

    final subtitleText = _isSeller
        ? 'Сатуучу'
        : (_email.isNotEmpty ? _email : '—');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F5F7),
      extendBodyBehindAppBar: true,

      // ── AppBar — размытие (settings стилинде) ──
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: isDark
                  ? Colors.black.withOpacity(0.30)
                  : Colors.white.withOpacity(0.40),
            ),
          ),
        ),
        foregroundColor: textColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          loc.get('profile'),
          style: AppTextStyles.headingSmall.copyWith(color: textColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _showEditSheet,
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
          ),
        ],
      ),

      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                20,
                120,
              ),
              child: Column(
                children: [
                  // ── АВАТАР КАРТОЧКАСЫ ──
                  _glassCard(
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Column(
                        children: [
                          // Аватар
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _onAvatarTap,
                                child: Container(
                                  width: 96, height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _avatarUrl == null
                                        ? const LinearGradient(colors: [
                                            Color(0xFFD97706),
                                            Color(0xFFEF4444)
                                          ])
                                        : null,
                                    image: _avatarUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(_avatarUrl!),
                                            fit: BoxFit.cover)
                                        : null,
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.15)
                                          : Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withOpacity(0.25),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: _avatarUrl == null
                                      ? Center(
                                          child: Text(
                                            _fullName.isNotEmpty
                                                ? _fullName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontSize: 36,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: GestureDetector(
                                  onTap: _onAvatarTap,
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.white,
                                          width: 2),
                                    ),
                                    child: _isUploadingPhoto
                                        ? const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : const Icon(Icons.camera_alt,
                                            color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Аты
                          Text(
                            _fullName.trim().isEmpty
                                ? loc.get('profile_no_name')
                                : _fullName.trim(),
                            style: AppTextStyles.headingMedium
                                .copyWith(color: textColor),
                          ),
                          const SizedBox(height: 4),

                          // Email / Сатуучу
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isSeller) ...[
                                const Icon(Icons.store_rounded,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                subtitleText,
                                style: AppTextStyles.bodyMedium
                                    .copyWith(color: subColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── МААЛЫМАТТАР КАРТОЧКАСЫ ──
                  _glassCard(
                    isDark: isDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _profileItem(
                            Icons.person_outline,
                            loc.get('profile_label_name'),
                            _fullName,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                          Divider(height: 1, color: divColor),
                          _profileItem(
                            _isSeller
                                ? Icons.store_outlined
                                : Icons.email_outlined,
                            _isSeller ? 'Аккаунт' : 'Email',
                            _isSeller
                                ? 'Сатуучу аккаунту'
                                : (_email.isNotEmpty ? _email : '—'),
                            textColor: textColor,
                            subColor: subColor,
                          ),
                          Divider(height: 1, color: divColor),
                          _profileItem(
                            Icons.phone_outlined,
                            loc.get('profile_label_phone'),
                            _phone,
                            textColor: textColor,
                            subColor: subColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── ЧЫГУУ КНОПКАСЫ — Glass стилинде ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: GestureDetector(
                        onTap: _signOut,
                        child: Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(
                                isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.error
                                  .withOpacity(isDark ? 0.25 : 0.20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout,
                                  color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                loc.get('profile_signout_btn'),
                                style: AppTextStyles.headingSmall
                                    .copyWith(color: AppColors.error),
                              ),
                            ],
                          ),
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

  Widget _profileItem(
    IconData icon,
    String label,
    String value, {
    required Color textColor,
    required Color subColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: subColor)),
              Text(value.isNotEmpty ? value : '—',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: textColor)),
            ],
          ),
        ],
      ),
    );
  }
}