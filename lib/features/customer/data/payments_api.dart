import '../../../core/network/api_client.dart';
import '../../../core/network/api_models.dart';

class PaymentsApi {
  PaymentsApi(this._client);

  final ApiClient _client;

  Future<WalletDto> wallet() async {
    final data = await _client.get('/wallet');
    return WalletDto.fromJson(data['wallet'] as Map<String, dynamic>);
  }

  Future<List<PaymentMethodDto>> listMethods() async {
    final data = await _client.get('/payment-methods');
    final list = data['paymentMethods'] as List<dynamic>? ?? [];
    return list
        .map((e) => PaymentMethodDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StripeSetupDto> createSetupIntent() async {
    final data = await _client.post('/payment-methods/setup-intent');
    return StripeSetupDto.fromJson(
      data['setup'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> deleteMethod(String id) async {
    await _client.delete('/payment-methods/$id');
  }

  Future<List<PaymentTransactionDto>> listTransactions() async {
    final data = await _client.get('/payments/transactions');
    final list = data['transactions'] as List<dynamic>? ?? [];
    return list
        .map((e) => PaymentTransactionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class StripeSetupDto {
  const StripeSetupDto({
    required this.customerId,
    required this.setupIntentId,
    required this.setupIntentClientSecret,
    required this.ephemeralKeySecret,
    required this.publishableKey,
  });

  final String customerId;
  final String setupIntentId;
  final String setupIntentClientSecret;
  final String ephemeralKeySecret;
  final String publishableKey;

  factory StripeSetupDto.fromJson(Map<String, dynamic> json) {
    return StripeSetupDto(
      customerId: json['customerId'] as String? ?? '',
      setupIntentId: json['setupIntentId'] as String? ?? '',
      setupIntentClientSecret:
          json['setupIntentClientSecret'] as String? ?? '',
      ephemeralKeySecret: json['ephemeralKeySecret'] as String? ?? '',
      publishableKey: json['publishableKey'] as String? ?? '',
    );
  }
}

class PaymentTransactionDto {
  const PaymentTransactionDto({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.direction,
    required this.createdAt,
    this.subtitle,
    this.scheduledStart,
  });

  final String id;
  final String title;
  final String? subtitle;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String direction;
  final DateTime createdAt;
  final DateTime? scheduledStart;

  bool get isPaid => status.toUpperCase() == 'PAID';
  bool get isIn => direction == 'in';

  String get amountLabel {
    final symbol = currency == 'GBP'
        ? '£'
        : currency == 'USD'
            ? '\$'
            : '';
    final sign = isIn ? '+' : '-';
    return '$sign$symbol${amount.toStringAsFixed(2)}';
  }

  factory PaymentTransactionDto.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionDto(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Payment',
      subtitle: json['subtitle'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      status: json['status'] as String? ?? 'UNPAID',
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      direction: json['direction'] as String? ?? 'out',
      createdAt: DateTime.parse(json['createdAt'] as String),
      scheduledStart: json['scheduledStart'] != null
          ? DateTime.parse(json['scheduledStart'] as String)
          : null,
    );
  }
}
