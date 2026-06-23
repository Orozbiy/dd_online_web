enum SellerStatus {
  pending,
  approved,
  rejected,
  blocked,
}

// ═══════════════════════════════════════
// ТӨЛӨМ МОДЕЛИ
// ═══════════════════════════════════════

class PaymentModel {
  final String month;
  final bool paid;
  final DateTime? paidAt;
  final double amount;
  final String? method; // 'auto_card' | 'manual' | null

  PaymentModel({
    required this.month,
    required this.paid,
    this.paidAt,
    required this.amount,
    this.method,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      month: json['month'] as String,
      paid: json['paid'] as bool,
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'] as String)
          : null,
      amount: (json['amount'] as num).toDouble(),
      method: json['method'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'paid': paid,
      'paidAt': paidAt?.toIso8601String(),
      'amount': amount,
      if (method != null) 'method': method,
    };
  }
}

// ═══════════════════════════════════════
// SELLER МОДЕЛИ (profiles таблицасынын row'у)
// ═══════════════════════════════════════

class SellerModel {
  final String uid;
  final String name;
  final String shopName;
  final String phone;
  final SellerStatus status;
  final DateTime createdAt;
  final String containerNumber;
  final List<PaymentModel> payments;
  final double? latitude;
  final double? longitude;

  final String storeType;  
  final String? marketName;  

  final bool autoPayEnabled;
  final String? cardToken;   // PayBox'тан алынган токен
  final String? cardMasked;  // "•••• 4242"
  final DateTime? nextPayDate;
  // ─────────────────────────────────────────
  

  SellerModel({
    required this.uid,
    required this.name,
    required this.shopName,
    required this.phone,
    required this.status,
    required this.createdAt,
    this.containerNumber = '',
    this.payments = const [],
    this.latitude,
    this.longitude,
    this.storeType = 'market',
    this.marketName,
    this.autoPayEnabled = false,
    this.cardToken,
    this.cardMasked,
    this.nextPayDate,
  });

  // ── COMPUTED GETTERS ─────────────────────

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasCard => cardToken != null && cardToken!.isNotEmpty;

  double? get lat => latitude;
  double? get lng => longitude;

  String get statusText {
    switch (status) {
      case SellerStatus.pending:
        return 'Күтүүдө';
      case SellerStatus.approved:
        return 'Бекитилди';
      case SellerStatus.rejected:
        return 'Четке кагылды';
      case SellerStatus.blocked:
        return 'Блоктолду';
    }
  }

  bool get currentMonthPaid {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final payment = payments.where((p) => p.month == currentMonth).firstOrNull;
    return payment?.paid ?? false;
  }

  int get unpaidCount => payments.where((p) => !p.paid).length;

  // ── FROM JSON (Supabase profiles row, snake_case) ────

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    final paymentsList = (json['payments'] as List<dynamic>?)
            ?.map((p) => PaymentModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return SellerModel(
      uid: json['id'] as String,
      name: json['full_name'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: _statusFromString(json['seller_status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(json['created_at'] as String),
      containerNumber: json['container_number'] as String? ?? '',
      payments: paymentsList,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      storeType: json['store_type'] as String? ?? 'market',
      marketName: json['market_name'] as String?,
      autoPayEnabled: json['auto_pay_enabled'] as bool? ?? false,
      cardToken: json['card_token'] as String?,
      cardMasked: json['card_masked'] as String?,
      nextPayDate: json['next_pay_date'] != null
          ? DateTime.parse(json['next_pay_date'] as String)
          : null,
    );
  }

  // ── TO JSON (Supabase profiles row, snake_case) ──────

  Map<String, dynamic> toJson() {
    return {
      'id': uid,
      'full_name': name,
      'shop_name': shopName,
      'phone': phone,
      'seller_status': status.name,
      'container_number': containerNumber,
      'payments': payments.map((p) => p.toJson()).toList(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'store_type': storeType,
      if (marketName != null) 'market_name': marketName,
      'auto_pay_enabled': autoPayEnabled,
      if (cardToken != null) 'card_token': cardToken,
      if (cardMasked != null) 'card_masked': cardMasked,
      if (nextPayDate != null) 'next_pay_date': nextPayDate!.toIso8601String(),
    };
  }

  // ── STATUS HELPER ────────────────────────

  static SellerStatus _statusFromString(String s) {
    switch (s) {
      case 'approved':
        return SellerStatus.approved;
      case 'rejected':
        return SellerStatus.rejected;
      case 'blocked':
        return SellerStatus.blocked;
      default:
        return SellerStatus.pending;
    }
  }

  // ── COPY WITH ────────────────────────────

  SellerModel copyWith({
    String? storeType,
    String? marketName,
    String? uid,
    String? name,
    String? shopName,
    String? phone,
    SellerStatus? status,
    DateTime? createdAt,
    String? containerNumber,
    List<PaymentModel>? payments,
    double? latitude,
    double? longitude,
    bool? autoPayEnabled,
    String? cardToken,
    String? cardMasked,
    DateTime? nextPayDate,
  }) {
    return SellerModel(
      storeType: storeType ?? this.storeType,
      marketName: marketName ?? this.marketName,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      shopName: shopName ?? this.shopName,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      containerNumber: containerNumber ?? this.containerNumber,
      payments: payments ?? this.payments,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
      cardToken: cardToken ?? this.cardToken,
      cardMasked: cardMasked ?? this.cardMasked,
      nextPayDate: nextPayDate ?? this.nextPayDate,
    );
  }
}
