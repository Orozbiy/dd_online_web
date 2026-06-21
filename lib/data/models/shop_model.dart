/// Дүкөн (магазин) моделі - Дордойдогу контейнер
class ShopModel {
  final String id;              // Дүкөнүн ID
  final String name;            // Дүкөнүн аты
  final String mapBlock;        // Картада жайгашкан орну (А-12, В-5 ж.б.)
  final String ownerId;         // Ээсинин ID
  final String? imageUrl;       // Дүкөнүн сүрөтү
  final String? description;    // Сүрөттөмөсү
  final double? rating;         // Рейтинги (1-5 жылдыз)
  final int? reviewCount;       // Сын-пикирлердин саны

  ShopModel({
    required this.id,
    required this.name,
    required this.mapBlock,
    required this.ownerId,
    this.imageUrl,
    this.description,
    this.rating,
    this.reviewCount,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] as String,
      name: json['name'] as String,
      mapBlock: json['mapBlock'] as String,
      ownerId: json['ownerId'] as String,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mapBlock': mapBlock,
      'ownerId': ownerId,
      'imageUrl': imageUrl,
      'description': description,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}
