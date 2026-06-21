/// Колдонуучу моделі - сатып алуучу же сатуучу болушу мүмкүн
class UserModel {
  final String uid;           // Уникалдуу ID
  final String phone;         // Телефон номери
  final String name;          // Аты-жөнү
  final String avatarUrl;     // Аватар сүрөтүнүн URL
  final String role;          // 'buyer' (сатып алуучу) же 'seller' (сатуучу)

  UserModel({
    required this.uid,
    required this.phone,
    required this.name,
    required this.avatarUrl,
    required this.role,
  });

  /// JSON ден модельге айлантуу
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String,
      role: json['role'] as String,
    );
  }

  /// Модельдүн JSON форматка айлантуу
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'phone': phone,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role,
    };
  }

  /// Модельди көчүрүп өзгөртүү
  UserModel copyWith({
    String? uid,
    String? phone,
    String? name,
    String? avatarUrl,
    String? role,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
    );
  }
}
