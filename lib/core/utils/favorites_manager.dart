import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/product_model.dart';
import '../supabase_client.dart';

/// Избранный товарларды башкаруу
/// ChangeNotifier кошулду — badge реалдуу убакытта жаңырат
class FavoritesManager extends ChangeNotifier {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  static const _kFavKey = 'favorites_items';

  final List<ProductModel> _favorites = [];

  List<ProductModel> get favorites => List.unmodifiable(_favorites);

  // --- SharedPreferences жүктөө ---
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFavKey);
    if (raw == null) return;
    try {
      final List decoded = jsonDecode(raw);
      _favorites.clear();
      _favorites.addAll(decoded.map((e) => ProductModel.fromJson(e)));
      notifyListeners();
    } catch (_) {}
  }

  // --- SharedPreferences сактоо ---
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_favorites.map((p) => p.toJson()).toList());
    await prefs.setString(_kFavKey, encoded);
  }

  bool isFavorite(String productId) {
    return _favorites.any((p) => p.id == productId);
  }

  void toggle(ProductModel product) {
    final wasLiked = isFavorite(product.id);

    if (wasLiked) {
      _favorites.removeWhere((p) => p.id == product.id);
      // ✅ likes_count - 1
      _updateLikesCount(product.id, increment: false);
    } else {
      _favorites.add(product);
      // ✅ likes_count + 1
      _updateLikesCount(product.id, increment: true);
    }

    _saveToPrefs();
    notifyListeners();
  }

  // ✅ ЖАҢЫ: Supabase'де likes_count жаңыртуу
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
}