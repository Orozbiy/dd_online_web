class ProductModel {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String shopId;
  final String? category;
  final String? description;
  final double? rating;
  final int? ratingCount;
  final int? inStock;
  final List<String> colors;
  final List<String> sizes;
  final String? shopName;
  final String? sellerUid;
  final double? discountedPrice;
  final bool hasPromotion;
  final double? latitude;
  final double? longitude;
  final String? region;
  final String? district;
  final double? distanceKm;
  final DateTime? createdAt;
  // ✅ ЖАҢЫ: статистика
  final int viewsCount;
  final int likesCount;
  final bool hasNegotiation;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.shopId,
    this.category,
    this.description,
    this.rating,
    this.ratingCount,
    this.inStock,
    this.colors = const [],
    this.sizes = const [],
    this.shopName,
    this.sellerUid,
    this.discountedPrice,
    this.hasPromotion = false,
    this.latitude,
    this.longitude,
    this.region,
    this.district,
    this.distanceKm,
    this.createdAt,
    this.viewsCount = 0, // ✅ ЖАҢЫ
    this.likesCount = 0, // ✅ ЖАҢЫ
    this.hasNegotiation = false,
  });

  /// Товар 10 күндөн жаш болсо — "Жаңы" badge көрсөтүлөт
  bool get isNew {
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!).inDays < 10;
  }

  /// Supabase 'products' row'дон (мүмкүн stores JOIN менен бирге)
  factory ProductModel.fromMap(Map<String, dynamic> data) {
    final images = List<String>.from(data['images'] as List? ?? []);
    final store = data['stores'] as Map<String, dynamic>?;

    return ProductModel(
      id: data['id'] as String? ?? '',
      name: data['title'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageUrl: images.isNotEmpty ? images.first : '',
      shopId: data['store_id'] as String? ?? '',
      category: data['category_id'] as String?,
      description: data['description'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      ratingCount: (data['rating_count'] as num?)?.toInt(),
      inStock: (data['in_stock'] as num?)?.toInt(),
      colors: List<String>.from(data['colors'] as List? ?? []),
      sizes: List<String>.from(data['sizes'] as List? ?? []),
      shopName: store?['store_name'] as String? ?? data['shop_name'] as String?,
      sellerUid: store?['owner_id'] as String? ?? data['seller_uid'] as String?,
      discountedPrice: (data['discounted_price'] as num?)?.toDouble(),
      hasPromotion: data['has_promotion'] as bool? ?? 
      false,
      hasNegotiation: (store?['has_negotiation'] as bool?) ?? false,

      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      region: data['region'] as String?,
      district: data['district'] as String?,
      createdAt: data['created_at'] != null
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
      // ✅ ЖАҢЫ
      viewsCount: (data['views_count'] as num?)?.toInt() ?? 0,
      likesCount: (data['likes_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) =>
      ProductModel.fromMap(json);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'price': price,
      'images': [imageUrl],
      'store_id': shopId,
      'category_id': category,
      'description': description,
      'rating': rating,
      'rating_count': ratingCount,
      'in_stock': inStock,
      'colors': colors,
      'sizes': sizes,
      'discounted_price': discountedPrice,
      'has_promotion': hasPromotion,
      'has_negotiation': hasNegotiation,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (region != null) 'region': region,
      if (district != null) 'district': district,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'views_count': viewsCount, // ✅ ЖАҢЫ
      'likes_count': likesCount, // ✅ ЖАҢЫ
    };
  }

  String get priceFormatted => '${price.toStringAsFixed(0)} с';

  String get distanceFormatted {
    if (distanceKm == null) return '';
    if (distanceKm! < 1) return '${(distanceKm! * 1000).toStringAsFixed(0)} м';
    return '${distanceKm!.toStringAsFixed(1)} км';
  }

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    String? shopId,
    String? category,
    String? description,
    double? rating,
    int? ratingCount,
    int? inStock,
    List<String>? colors,
    List<String>? sizes,
    String? shopName,
    String? sellerUid,
    double? discountedPrice,
    bool? hasPromotion,
    double? latitude,
    double? longitude,
    String? region,
    String? district,
    double? distanceKm,
    DateTime? createdAt,
    int? viewsCount, // ✅ ЖАҢЫ
    int? likesCount, // ✅ ЖАҢЫ
    bool? hasNegotiation,

  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      shopId: shopId ?? this.shopId,
      category: category ?? this.category,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      inStock: inStock ?? this.inStock,
      colors: colors ?? this.colors,
      sizes: sizes ?? this.sizes,
      shopName: shopName ?? this.shopName,
      sellerUid: sellerUid ?? this.sellerUid,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      hasPromotion: hasPromotion ?? this.hasPromotion,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      region: region ?? this.region,
      district: district ?? this.district,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
      viewsCount: viewsCount ?? this.viewsCount, // ✅ ЖАҢЫ
      likesCount: likesCount ?? this.likesCount,
      hasNegotiation: hasNegotiation ?? this.hasNegotiation,
       // ✅ ЖАҢЫ
    );
  }
}