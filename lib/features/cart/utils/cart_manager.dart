import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/models/product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;
  String? selectedSize;

  CartItem({required this.product, this.quantity = 1, this.selectedSize});

  double get totalPrice => product.price * quantity;

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
        'selectedSize': selectedSize,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: ProductModel.fromJson(json['product']),
        quantity: json['quantity'] as int,
        selectedSize: json['selectedSize'] as String?,
      );
}

class CartManager {
  static CartManager? _instance;
  static CartManager get instance {
    _instance ??= CartManager._internal();
    return _instance!;
  }
  CartManager._internal();

  static const _kCartKey = 'cart_items';

  final List<CartItem> _items = [];

  List<CartItem> get items => List.from(_items);

  int get totalCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice => _items.fold(0, (sum, i) => sum + i.totalPrice);

  // --- SharedPreferences жүктөө ---
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCartKey);
    if (raw == null) return;
    try {
      final List decoded = jsonDecode(raw);
      _items.clear();
      _items.addAll(decoded.map((e) => CartItem.fromJson(e)));
    } catch (_) {}
  }

  // --- SharedPreferences сактоо ---
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_kCartKey, encoded);
  }

  void addItem(ProductModel product, {String? size}) {
    final existing = _items.firstWhere(
      (i) => i.product.id == product.id && i.selectedSize == size,
      orElse: () => CartItem(product: product, quantity: 0, selectedSize: size),
    );
    if (_items.contains(existing)) {
      existing.quantity++;
    } else {
      existing.quantity = 1;
      _items.add(existing);
    }
    _saveToPrefs();
  }

  void removeItem(String productId, {String? size}) {
    _items.removeWhere((i) => i.product.id == productId && i.selectedSize == size);
    _saveToPrefs();
  }

  void increaseQuantity(CartItem item) {
    item.quantity++;
    _saveToPrefs();
  }

  void decreaseQuantity(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }
    _saveToPrefs();
  }

  void clear() {
    _items.clear();
    _saveToPrefs();
  }

  bool contains(String productId) => _items.any((i) => i.product.id == productId);
}
