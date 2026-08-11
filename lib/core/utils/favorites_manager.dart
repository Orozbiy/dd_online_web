// lib/core/utils/favorites_manager.dart
// ── Тандамалар башкаргычы: товарлар + дүкөндөр ──

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/product_model.dart';
import '../supabase_client.dart';

/// Избранный товарлар + дүкөндөрдү башкаруу
/// ChangeNotifier — badge реалдуу убакытта жаңырат
class FavoritesManager extends ChangeNotifier {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  static const _kFavKey    = 'favorites_items';
  static const _kStoresKey = 'favorites_store_ids';

  final List<ProductModel> _favorites = [];
  final Set<String>        _storeIds  = {};

  List<ProductModel> get favorites        => List.unmodifiable(_favorites);
  List<String>       get favoriteStoreIds => List.unmodifiable(_storeIds.toList());

  // ══════════════════════════════════════════════════
  // ЖҮКТӨӨ
  // ══════════════════════════════════════════════════

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Товарлар
    final raw = prefs.getString(_kFavKey);
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        _favorites.clear();
        _favorites.addAll(decoded.map((e) => ProductModel.fromJson(e)));
      } catch (_) {}
    }

    // Дүкөндөр
    final storesRaw = prefs.getString(_kStoresKey);
    if (storesRaw != null) {
      try {
        final List decoded = jsonDecode(storesRaw);
        _storeIds.clear();
        _storeIds.addAll(decoded.cast<String>());
      } catch (_) {}
    }

    notifyListeners();
  }

  // ══════════════════════════════════════════════════
  // САКТОО
  // ══════════════════════════════════════════════════

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_favorites.map((p) => p.toJson()).toList());
    await prefs.setString(_kFavKey, encoded);
  }

  Future<void> _saveStoresToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoresKey, jsonEncode(_storeIds.toList()));
  }

  // ══════════════════════════════════════════════════
  // ТОВАРЛАР
  // ══════════════════════════════════════════════════

  bool isFavorite(String productId) {
    return _favorites.any((p) => p.id == productId);
  }

  void toggle(ProductModel product) {
    final wasLiked = isFavorite(product.id);

    if (wasLiked) {
      _favorites.removeWhere((p) => p.id == product.id);
      _updateLikesCount(product.id, increment: false);

      // Бул дүкөндүн башка товары жок болсо — дүкөндү да алып сал
      if (product.shopId.isNotEmpty) {
        final hasOther = _favorites.any((p) => p.shopId == product.shopId);
        if (!hasOther) {
          _storeIds.remove(product.shopId);
          _saveStoresToPrefs();
        }
      }
    } else {
      _favorites.add(product);
      _updateLikesCount(product.id, increment: true);

      // Товардын дүкөнүн автоматтык сакта
      if (product.shopId.isNotEmpty) {
        _storeIds.add(product.shopId);
        _saveStoresToPrefs();
      }
    }

    _saveToPrefs();
    notifyListeners();
  }

  Future<void> _updateLikesCount(String productId, {required bool increment}) async {
    try {
      await supabase.rpc(
        increment ? 'increment_product_likes' : 'decrement_product_likes',
        params: {'product_id': productId},
      );
    } catch (e) {
      debugPrint('⚠️ likes_count жаңыртуу ката: $e');
    }
  }

  int get count => _favorites.length;

  // ══════════════════════════════════════════════════
  // ДҮКӨНДӨР
  // ══════════════════════════════════════════════════

  bool isStoreFavorite(String storeId) => _storeIds.contains(storeId);

  void toggleStore(String storeId) {
    if (_storeIds.contains(storeId)) {
      _storeIds.remove(storeId);
    } else {
      _storeIds.add(storeId);
    }
    _saveStoresToPrefs();
    notifyListeners();
  }

  int get storeCount => _storeIds.length;
}