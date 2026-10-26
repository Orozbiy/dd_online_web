// lib/features/admin/screens/admin_complaints_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_text_styles.dart';
import '../../../core/supabase_client.dart';
import '../../product_detail/widgets/fullscreen_image_screen.dart';

/// Скриншоттор сакталуучу Supabase Storage bucket
const String _kShotBucket = 'complaint-screenshots';

/// Арыз кимге (кайсы сатуучуга/дүкөнгө) айтылганы
class _SellerInfo {
  final String shop;
  final String seller;
  final String container;
  const _SellerInfo(this.shop, this.seller, this.container);

  bool get isEmpty => shop.isEmpty && seller.isEmpty;

  /// "Дүкөн (Сатуучу)" форматында
  String get label {
    if (shop.isNotEmpty && seller.isNotEmpty && shop != seller) {
      return '$shop ($seller)';
    }
    return shop.isNotEmpty ? shop : seller;
  }
}

_SellerInfo _sellerInfoOf(Map<String, dynamic> c) {
  String s(dynamic v) => (v as String?)?.trim() ?? '';
  final product = c['products'] as Map?;
  final store = product?['stores'] as Map?;

  var shop = s(c['shop_name']);
  if (shop.isEmpty) shop = s(store?['store_name']);
  final seller = s(c['seller_name']);
  var container = s(c['container_number']);
  if (container.isEmpty && store != null) {
    container = [s(store['market']), s(store['district'])]
        .where((e) => e.isNotEmpty)
        .join(', ');
  }
  return _SellerInfo(shop, seller, container);
}

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = true;

  // Тандоо режими (белгилеп өчүрүү үчүн)
  bool _selectMode = false;
  final Set<String> _selected = {};

  final _searchCtrl = TextEditingController();
  String _query = '';

  // Панель bottom sheet ичинде ачылгандыктан, snackbar'ды өз ичинде көрсөтөбүз
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _idOf(Map<String, dynamic> c) => c['id'].toString();

  Future<void> _load() async {
    setState(() => _isLoading = true);
    List data;
    try {
      // products → stores аркылуу сатуучунун аты (эски арыздар үчүн да)
      data = await supabase
          .from('complaints')
          .select('*, products(title, stores(store_name, market, district))')
          .order('created_at', ascending: false);
    } catch (e) {
      debugPrint('⚠️ AdminComplaintsScreen (nested select): $e');
      try {
        data = await supabase
            .from('complaints')
            .select('*, products(title)')
            .order('created_at', ascending: false);
      } catch (e2) {
        debugPrint('❌ AdminComplaintsScreen: $e2');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _complaints = data.cast<Map<String, dynamic>>();
      _selected.removeWhere((id) => !_complaints.any((c) => _idOf(c) == id));
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _visible {
    if (_query.isEmpty) return _complaints;
    final q = _query.toLowerCase();
    return _complaints.where((c) {
      final info = _sellerInfoOf(c);
      final productName = (c['products'] as Map?)?['title'] as String? ?? '';
      final haystack = [
        info.shop,
        info.seller,
        info.container,
        c['sender_name'],
        c['sender_email'],
        c['topic'],
        c['purpose'],
        productName,
      ].map((e) => (e ?? '').toString().toLowerCase()).join(' | ');
      return haystack.contains(q);
    }).toList();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    (_messengerKey.currentState ?? ScaffoldMessenger.of(context))
        .showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  // ── Окулду деп белгилөө ──
  Future<void> _markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await supabase
          .from('complaints')
          .update({'is_read': true}).inFilter('id', ids);
      if (!mounted) return;
      setState(() {
        for (final c in _complaints) {
          if (ids.contains(_idOf(c))) c['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('❌ markRead: $e');
      _snack('Ката: $e', error: true);
    }
  }

  // ── Өчүрүү ──
  Future<void> _delete(List<String> ids) async {
    if (ids.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Өчүрүү', style: AppTextStyles.headingSmall),
        content: Text(
          ids.length == 1
              ? 'Бул арызды өчүрөсүзбү?'
              : '${ids.length} арызды өчүрөсүзбү?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Жок', style: TextStyle(color: AppColors.grey500)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өчүрүү', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Өчүрүлө турган арыздардын скриншоттору (Storage'тен да тазалайбыз)
    final shotPaths = <String>[];
    for (final c in _complaints) {
      if (!ids.contains(_idOf(c))) continue;
      final url = (c['screenshot_url'] as String?) ?? '';
      final marker = '/$_kShotBucket/';
      final idx = url.indexOf(marker);
      if (idx != -1) {
        shotPaths.add(Uri.decodeComponent(url.substring(idx + marker.length)));
      }
    }

    try {
      final deleted = await supabase
          .from('complaints')
          .delete()
          .inFilter('id', ids)
          .select('id');
      if ((deleted as List).isEmpty) {
        _snack(
          'Өчүрүлгөн жок. Supabase\'де SQL миграцияны (delete уруксаты) иштетиңиз.',
          error: true,
        );
        return;
      }
      if (shotPaths.isNotEmpty) {
        try {
          await supabase.storage.from(_kShotBucket).remove(shotPaths);
        } catch (e) {
          debugPrint('⚠️ screenshot storage remove: $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _complaints.removeWhere((c) => ids.contains(_idOf(c)));
        _selected.removeAll(ids);
        if (_selected.isEmpty) _selectMode = false;
      });
      _snack('Өчүрүлдү: ${deleted.length}');
    } catch (e) {
      debugPrint('❌ delete complaints: $e');
      _snack('Ката: $e', error: true);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  void _openDetail(Map<String, dynamic> c, bool isDark) {
    final id = _idOf(c);
    if (!(c['is_read'] as bool? ?? false)) _markRead([id]);
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _ComplaintDetailSheet(
        complaintId: id,
        senderName: (c['sender_name'] as String?)?.isNotEmpty == true
            ? c['sender_name'] as String
            : 'Белгисиз',
        senderEmail: c['sender_email'] as String? ?? '',
        topic: c['topic'] as String? ?? '',
        purpose: c['purpose'] as String? ?? '',
        details: c['details'] as String? ?? '',
        productName: (c['products'] as Map?)?['title'] as String? ?? '',
        seller: _sellerInfoOf(c),
        screenshotUrl: (c['screenshot_url'] as String?) ?? '',
        dateStr: _fmtDate(createdAt),
        isDark: isDark,
        onDelete: () {
          Navigator.pop(sheetCtx);
          _delete([id]);
        },
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}.${l.year}';
  }

  // ── Жогорку панель: издөө + тандоо аракеттери ──
  Widget _buildToolbar(bool isDark, Color textColor, Color subColor) {
    final unread =
        _complaints.where((c) => !(c['is_read'] as bool? ?? false)).length;
    final visibleIds = _visible.map(_idOf).toList();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selected.contains);

    if (_selectMode) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Жабуу',
              icon: Icon(Icons.close, color: textColor),
              onPressed: _exitSelectMode,
            ),
            Expanded(
              child: Text(
                'Тандалды: ${_selected.length}',
                style: AppTextStyles.labelLarge.copyWith(color: textColor),
              ),
            ),
            IconButton(
              tooltip: allSelected ? 'Тандоону алып салуу' : 'Баарын тандоо',
              icon: Icon(
                allSelected ? Icons.deselect : Icons.select_all,
                color: textColor,
              ),
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.removeAll(visibleIds);
                } else {
                  _selected.addAll(visibleIds);
                }
              }),
            ),
            IconButton(
              tooltip: 'Окулду деп белгилөө',
              icon: Icon(Icons.done_all_rounded, color: textColor),
              onPressed: _selected.isEmpty
                  ? null
                  : () => _markRead(_selected.toList()),
            ),
            IconButton(
              tooltip: 'Өчүрүү',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _selected.isEmpty ? subColor : const Color(0xFFEF4444),
              ),
              onPressed:
                  _selected.isEmpty ? null : () => _delete(_selected.toList()),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: textColor, fontSize: 14),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Сатуучу, дүкөн, товар боюнча издөө...',
                  hintStyle: TextStyle(color: subColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: subColor, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 18, color: subColor),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF5F5F5),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _complaints.isEmpty
                ? null
                : () => setState(() => _selectMode = true),
            icon: const Icon(Icons.checklist_rounded, size: 20),
            label: Text(unread > 0 ? 'Тандоо ($unread жаңы)' : 'Тандоо'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : AppColors.grey500;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Арыз жок',
              style: AppTextStyles.headingSmall.copyWith(color: subColor),
            ),
          ],
        ),
      );
    }

    final items = _visible;

    return Column(
      children: [
        _buildToolbar(isDark, textColor, subColor),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.primary,
            child: items.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Text('Табылган жок',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: subColor)),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _buildCard(items[i], isDark, bgColor, textColor, subColor),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> c, bool isDark, Color bgColor,
      Color textColor, Color subColor) {
    final id = _idOf(c);
    final isRead = c['is_read'] as bool? ?? false;
    final isSelected = _selected.contains(id);
    final createdAt = DateTime.tryParse(c['created_at'] as String? ?? '');
    final dateStr = _fmtDate(createdAt);

    final senderName = (c['sender_name'] as String?)?.isNotEmpty == true
        ? c['sender_name'] as String
        : 'Белгисиз';
    final senderEmail = c['sender_email'] as String? ?? '';
    final topic = c['topic'] as String? ?? '';
    final purpose = c['purpose'] as String? ?? '';
    final productName = (c['products'] as Map?)?['title'] as String? ?? '';
    final seller = _sellerInfoOf(c);
    final screenshotUrl = (c['screenshot_url'] as String?) ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withOpacity(0.12)
            : (isRead
                ? bgColor
                : (isDark
                    ? const Color(0xFFEF4444).withOpacity(0.08)
                    : const Color(0xFFFFF1F0))),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isRead
                  ? (isDark ? Colors.white12 : AppColors.grey200)
                  : const Color(0xFFEF4444).withOpacity(0.35)),
          width: isSelected ? 1.6 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: _selectMode
            ? Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                onChanged: (_) => _toggle(id),
              )
            : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isRead
                      ? AppColors.grey200
                      : const Color(0xFFEF4444).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: isRead ? AppColors.grey400 : const Color(0xFFEF4444),
                  size: 22,
                ),
              ),
        trailing: screenshotUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CachedNetworkImage(
                    imageUrl: screenshotUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.grey200),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.grey200,
                      child: const Icon(Icons.broken_image_outlined,
                          size: 20, color: AppColors.grey400),
                    ),
                  ),
                ),
              )
            : null,
        title: Row(
          children: [
            Expanded(
              child: Text(
                senderName,
                style: AppTextStyles.labelLarge.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isRead)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Жаңы',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // ── Арыз КИМГЕ айтылды ──
            if (!seller.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Кимге: ${seller.label}'
                        '${seller.container.isNotEmpty ? ' • ${seller.container}' : ''}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (senderEmail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.email_outlined, size: 13, color: subColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      senderEmail,
                      style: AppTextStyles.labelSmall.copyWith(color: subColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (topic.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  topic,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ],
            if (purpose.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                purpose,
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (productName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '📦 $productName',
                style: AppTextStyles.labelSmall.copyWith(color: subColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: AppTextStyles.labelSmall.copyWith(color: subColor),
            ),
          ],
        ),
        onTap: () {
          if (_selectMode) {
            _toggle(id);
          } else {
            _openDetail(c, isDark);
          }
        },
        onLongPress: () {
          if (!_selectMode) {
            setState(() {
              _selectMode = true;
              _selected.add(id);
            });
          }
        },
      ),
    );
  }
}

// ── Арыздын толук маалыматы ──
class _ComplaintDetailSheet extends StatelessWidget {
  final String complaintId;
  final String senderName;
  final String senderEmail;
  final String topic;
  final String purpose;
  final String details;
  final String productName;
  final _SellerInfo seller;
  final String screenshotUrl;
  final String dateStr;
  final bool isDark;
  final VoidCallback onDelete;

  const _ComplaintDetailSheet({
    required this.complaintId,
    required this.senderName,
    required this.senderEmail,
    required this.topic,
    required this.purpose,
    required this.details,
    required this.productName,
    required this.seller,
    required this.screenshotUrl,
    required this.dateStr,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : AppColors.grey500;
    final handleColor = isDark ? const Color(0xFF3A3A3A) : Colors.grey[300]!;

    return Container(
      color: bg,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Color(0xFFEF4444), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(senderName,
                          style: AppTextStyles.headingSmall
                              .copyWith(color: textColor)),
                      if (senderEmail.isNotEmpty)
                        Text(senderEmail,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: subColor)),
                    ],
                  ),
                ),
                Text(dateStr,
                    style: AppTextStyles.labelSmall.copyWith(color: subColor)),
              ],
            ),
            const SizedBox(height: 16),
            if (!seller.isEmpty) ...[
              _row(
                'Кимге (сатуучу)',
                '🏪 ${seller.label}'
                    '${seller.container.isNotEmpty ? '\n📍 ${seller.container}' : ''}',
                textColor,
                subColor,
              ),
              const SizedBox(height: 10),
            ],
            if (topic.isNotEmpty) ...[
              _row('Тема', topic, textColor, subColor),
              const SizedBox(height: 10),
            ],
            if (purpose.isNotEmpty) ...[
              _row('Максат', purpose, textColor, subColor),
              const SizedBox(height: 10),
            ],
            if (details.isNotEmpty) ...[
              _row('Кошумча маалымат', details, textColor, subColor),
              const SizedBox(height: 10),
            ],
            if (productName.isNotEmpty) ...[
              _row('Товар', '📦 $productName', textColor, subColor),
              const SizedBox(height: 10),
            ],
            if (screenshotUrl.isNotEmpty) ...[
              Text('Скриншот',
                  style: AppTextStyles.labelSmall.copyWith(color: subColor)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImageScreen(
                      images: [screenshotUrl],
                      initialIndex: 0,
                      heroTag: 'complaint_shot_$complaintId',
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: screenshotUrl,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    placeholder: (_, __) => Container(
                      height: 160,
                      color: AppColors.grey200,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 100,
                      color: AppColors.grey200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.grey400),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                label: const Text('Арызды өчүрүү'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color text, Color sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: sub)),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.bodyMedium.copyWith(color: text)),
      ],
    );
  }
}
