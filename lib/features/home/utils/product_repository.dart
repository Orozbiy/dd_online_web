import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/supabase_client.dart';
import '../../../data/models/product_model.dart';

/// Товарларды Supabase'тен жүктөө:
/// пагинация + персонализация + поиск + "Мага жакын" geo-сорттоо.
class ProductRepository {
  ProductRepository._();
  static final ProductRepository instance = ProductRepository._();

  static const int pageSize = 20;

  double _randomSeed =
      DateTime.now().millisecondsSinceEpoch % 1000000 / 1000000;

  final Set<String> _shownIds = {};

  void refreshSeed() {
    _randomSeed = DateTime.now().millisecondsSinceEpoch % 1000000 / 1000000;
    debugPrint('🔄 Seed жаңырды, shownIds=${_shownIds.length} сакталды');
  }

  static const List<String> bannedWords = [
    'төш', 'сутюк', 'ички кийим', 'бюстгальтер', 'трус', 'стринг',
    'корсет', 'купальник', 'лифчик', 'танга', 'бикини',
    'трусы', 'стринги', 'нижнее бельё',
    'нижнее', 'белье', 'бельё',
  ];

  // ══════════════════════════════════════════════════════════════════
  // ЖАРДАМЧЫ: категория фильтри
  //
  // ✅ НЕГИЗГИ ОҢДОО:
  // Мурда: .eq('category_id', '1')  → '1_2', '1_3' табылбайт
  // Азыр:  .like('category_id', '1%') → '1', '1_2', '1_3' баары табылат
  //
  // Эгер кичи категория тандалса (мис. '1_2') — так дал келүү:
  // .like('category_id', '1_2%') → '1_2' гана табылат
  // ══════════════════════════════════════════════════════════════════

  bool _isMainCategory(String categoryId) {
    // Кичи категория '_' белгисин камтыйт: '1_2', '4_3' ж.б.
    // Негизги категория: '1', '4', '12' ж.б.
    return !categoryId.contains('_');
  }

  // ══════════════════════════════════════════════════════════════════
  // GPS
  // ══════════════════════════════════════════════════════════════════

  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // КӨРҮҮ ТАРЫХЫН ЖАЗУУ
  // ══════════════════════════════════════════════════════════════════

  Future<void> recordProductView(ProductModel product) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('product_views').upsert({
        'user_id': userId,
        'product_id': product.id,
        'category_id': product.category ?? '',
        'viewed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,product_id');

      debugPrint('👁️ view жазылды: ${product.name}');
    } catch (e) {
      debugPrint('⚠️ recordProductView: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ПЕРСОНАЛИЗАЦИЯЛАНГАН ЛЕНТА
  // ══════════════════════════════════════════════════════════════════
Future<List<ProductModel>> fetchProducts({
  int offset = 0,
  String? categoryId,
  String? region,
}) async {
  // ✅ КОШУУ: категория тандалганда shownIds тазалансын
  if (categoryId != null && categoryId.isNotEmpty && offset == 0) {
    _shownIds.clear();
    debugPrint('🗑️ shownIds тазаланды (категория: $categoryId)');
  }

  final userId = supabase.auth.currentUser?.id;

  if (userId != null && categoryId == null && region == null) {
    return await _fetchPersonalized(userId: userId, offset: offset);
  }

  return await _fetchRandom(
    offset: offset,
    categoryId: categoryId,
    region: region,
  );
}

Future<List<ProductModel>> _fetchPersonalized({
  required String userId,
  int offset = 0,
}) async {
  try {
    final data = await supabase.rpc(
      'get_personalized_feed',
      params: {
        'p_user_id': userId,
        'p_offset': offset,
        'p_limit': pageSize,
      },
    );
      final results = _mapAndFilter(data as List);
      final fresh = results.where((p) => !_shownIds.contains(p.id)).toList();

      List<ProductModel> result;

      if (fresh.length >= pageSize) {
        result = fresh.take(pageSize).toList();
      } else {
        final extra = await supabase.rpc(
          'get_random_feed',
          params: {
            'p_seed': _randomSeed,
            'p_offset': 0,
            'p_limit': pageSize * 3,
            if (_shownIds.isNotEmpty) 'p_exclude_ids': _shownIds.toList(),
          },
        );
        final extraMapped = _mapAndFilter(extra as List);
        final seenInFresh = fresh.map((p) => p.id).toSet();
        final extraFresh =
            extraMapped.where((p) => !seenInFresh.contains(p.id)).toList();
        result = [...fresh, ...extraFresh].take(pageSize).toList();
      }

      if (result.isEmpty) {
        debugPrint('🔁 Баардык товар көрүлдү — тарых тазаланат');
        _shownIds.clear();
        return await _fetchPersonalized(userId: userId, offset: offset);
      }

      for (final p in result) _shownIds.add(p.id);
      debugPrint(
          '📦 personalized: ${result.length} товар, shownIds=${_shownIds.length}');
      return result;
    } catch (e) {
      debugPrint('⚠️ _fetchPersonalized ката: $e → random жүктөлөт');
      return await _fetchRandom(offset: offset);
    }
  }

  Future<List<ProductModel>> _fetchRandom({
    int offset = 0,
    String? categoryId,
    String? region,
    int? extraLimit,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_seed': _randomSeed,
        'p_offset': offset,
        'p_limit': extraLimit ?? pageSize,
        if (_shownIds.isNotEmpty) 'p_exclude_ids': _shownIds.toList(),
      };

      // ✅ RPC'га категория жиберебиз — RPC ичинде LIKE колдонушу керек
      // Эгер RPC LIKE колдонбосо — fallback'та оңдолот
      if (categoryId != null && categoryId.isNotEmpty) {
        params['p_category_id'] = categoryId;
      }

      final data = await supabase.rpc('get_random_feed', params: params);
      var result = _mapAndFilter(data as List);

      // ✅ ОҢДОО: RPC негизги категория боюнча чыпкаласа,
      // кичи категориялардагы товарлар чыкпайт.
      // Жергиликтүү фильтр кошобуз.
      if (categoryId != null && categoryId.isNotEmpty) {
        result = _filterByCategory(result, categoryId);
      }

      for (final p in result) _shownIds.add(p.id);
      debugPrint('📦 random: ${result.length} товар, shownIds=${_shownIds.length}');
      return result;
    } catch (e) {
      debugPrint('⚠️ _fetchRandom RPC ката: $e → fallback');
      return await _fetchFallback(
        offset: offset,
        categoryId: categoryId,
        region: region,
        limit: extraLimit ?? pageSize,
      );
    }
  }

  /// ✅ Жергиликтүү категория фильтри
  /// Негизги категория '1' → '1', '1_2', '1_3'... баарын кайтарат
  /// Кичи категория '1_2' → '1_2' гана кайтарат
  List<ProductModel> _filterByCategory(
    List<ProductModel> products, String categoryId) {
  if (_isMainCategory(categoryId)) {
    return products
        .where((p) =>
            p.category != null &&
            (p.category == categoryId ||
                p.category!.startsWith('${categoryId}_'))) // ✅ '1_' менен башталган гана
        .toList();
  } else {
    return products.where((p) => p.category == categoryId).toList();
  }
}

  /// Fallback: RPC жок болсо жөнөкөй Supabase query.
  Future<List<ProductModel>> _fetchFallback({
    int offset = 0,
    String? categoryId,
    String? region,
    int limit = 10,
  }) async {
    var query = supabase
        .from('products')
        .select('*, stores(store_name, owner_id)')
        .eq('is_active', true);

    // ✅ НЕГИЗГИ ОҢДОО: .eq → .like
    // '1'   → LIKE '1%'   → '1', '1_2', '1_3' баары табылат
    // '1_2' → LIKE '1_2%' → '1_2' гана табылат
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.like('category_id', '$categoryId%');
    }

    if (region != null && region.isNotEmpty) {
      query = query.eq('region', region);
    }

    final rng = Random((_randomSeed * 1000000).toInt());
    final data = await query.order('created_at', ascending: false);
    final all = _mapAndFilter(data);
    all.shuffle(rng);

    final unseen = all.where((p) => !_shownIds.contains(p.id)).toList();

    if (unseen.length < limit && all.length >= limit) {
      debugPrint('🔁 Баардык товар көрүлдү — тарых тазаланат');
      _shownIds.clear();
    }

    final source = unseen.length >= limit
        ? unseen
        : all.where((p) => !_shownIds.contains(p.id)).toList();
    final result = source.take(limit).toList();

    for (final p in result) _shownIds.add(p.id);

    debugPrint(
        '📦 fallback: берилди=${result.length}, unseen=${unseen.length}, shownIds=${_shownIds.length}');
    return result;
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ ЖАҢЫ ТОВАРЛАР
  // ══════════════════════════════════════════════════════════════════

  Future<List<ProductModel>> fetchNewest({
    String? categoryId,
    int limit = 40,
  }) async {
    try {
      var query = supabase
          .from('products')
          .select('*, stores(store_name, owner_id)')
          .eq('is_active', true);

      // ✅ ОҢДОО: .eq → .like
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.like('category_id', '$categoryId%');
      }

      final data =
          await query.order('created_at', ascending: false).limit(limit);

      return _mapAndFilter(data as List);
    } catch (e) {
      debugPrint('⚠️ fetchNewest ката: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // ✅ ТААНЫМАЛ ТОВАРЛАР
  // ══════════════════════════════════════════════════════════════════

  Future<List<ProductModel>> fetchPopular({
    String? categoryId,
    int limit = 40,
  }) async {
    try {
      var query = supabase
          .from('products')
          .select('*, stores(store_name, owner_id)')
          .eq('is_active', true)
          .not('rating', 'is', null);

      // ✅ ОҢДОО: .eq → .like
      if (categoryId != null && categoryId.isNotEmpty) {
        query = query.like('category_id', '$categoryId%');
      }

      final data = await query
          .order('rating', ascending: false)
          .order('rating_count', ascending: false)
          .limit(limit);

      return _mapAndFilter(data as List);
    } catch (e) {
      debugPrint('⚠️ fetchPopular ката: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // НОРМАЛИЗАЦИЯ
  // ══════════════════════════════════════════════════════════════════

  static String _normalize(String input) {
    const Map<String, String> table = {
      'ү': 'у', 'Ү': 'у',
      'ө': 'о', 'Ө': 'о',
      'ң': 'н', 'Ң': 'н',
      'ғ': 'г', 'Ғ': 'г',
      'і': 'и', 'І': 'и',
      'ё': 'е', 'Ё': 'е',
    };

    var result = input.toLowerCase();
    for (final entry in table.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════
  // ПОИСК
  // ══════════════════════════════════════════════════════════════════

  Future<List<ProductModel>> searchProducts({
    required String query,
    String? categoryId,
    int limit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalized = _normalize(trimmed);

    try {
      final params = <String, dynamic>{
        'search_query': normalized,
        'result_limit': limit,
      };
      if (categoryId != null && categoryId.isNotEmpty) {
        params['p_category_id'] = categoryId;
      }

      final data = await supabase.rpc(
        'search_products_normalized',
        params: params,
      );

      var results = _mapAndFilter(data as List);

      // ✅ ОҢДОО: RPC так дал келүү берсе — жергиликтүү фильтр
      if (categoryId != null && categoryId.isNotEmpty) {
        results = _filterByCategory(results, categoryId);
      }

      if (results.isNotEmpty) return results;

      return await _searchFallback(
        normalized: normalized,
        original: trimmed,
        categoryId: categoryId,
        limit: limit,
      );
    } catch (e) {
      debugPrint('⚠️ searchProducts RPC ката: $e → fallback');
      return await _searchFallback(
        normalized: normalized,
        original: trimmed,
        categoryId: categoryId,
        limit: limit,
      );
    }
  }

  Future<List<ProductModel>> _searchFallback({
    required String normalized,
    required String original,
    String? categoryId,
    int limit = 50,
  }) async {
    final queries = [
      _ilikeSearch(pattern: normalized, categoryId: categoryId, limit: limit),
      if (normalized != original)
        _ilikeSearch(pattern: original, categoryId: categoryId, limit: limit),
    ];

    final futures = await Future.wait(queries);

    final seen = <String>{};
    final merged = <ProductModel>[];
    for (final list in futures) {
      for (final p in list) {
        if (seen.add(p.id)) merged.add(p);
      }
    }

    merged.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return merged.take(limit).toList();
  }

  Future<List<ProductModel>> _ilikeSearch({
    required String pattern,
    String? categoryId,
    int limit = 50,
  }) async {
    try {
      var q = supabase
          .from('products')
          .select('*, stores(store_name, owner_id)')
          .eq('is_active', true)
          .ilike('title', '%$pattern%');

      // ✅ ОҢДОО: .eq → .like
      if (categoryId != null && categoryId.isNotEmpty) {
        q = q.like('category_id', '$categoryId%');
      }

      final data = await q.order('rating', ascending: false).limit(limit);
      return _mapAndFilter(data);
    } catch (e) {
      debugPrint('❌ _ilikeSearch ката: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // МАГА ЖАКЫН
  // ══════════════════════════════════════════════════════════════════

  Future<List<ProductModel>> fetchProductsNearby({
    required double lat,
    required double lng,
    double radiusKm = 50,
    int limit = pageSize,
    String? categoryId,
  }) async {
    final params = <String, dynamic>{
      'user_lat': lat,
      'user_lng': lng,
      'radius_km': radiusKm,
      'result_limit': limit,
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      params['p_category_id'] = categoryId;
    }

    final data = await supabase.rpc('products_nearby', params: params);
    var result = _mapAndFilter(data as List);

    // ✅ ОҢДОО: жергиликтүү фильтр кошулду
    if (categoryId != null && categoryId.isNotEmpty) {
      result = _filterByCategory(result, categoryId);
    }

    return result;
  }

  // ══════════════════════════════════════════════════════════════════
  // ЖАРДАМЧЫ
  // ══════════════════════════════════════════════════════════════════

  List<ProductModel> _mapAndFilter(List<dynamic> rows) {
    return rows
        .cast<Map<String, dynamic>>()
        .map((row) => ProductModel.fromMap(row))
        .where((p) {
          final name = p.name.toLowerCase();
          return !bannedWords.any((w) => name.contains(w.toLowerCase()));
        })
        .toList();
  }
}