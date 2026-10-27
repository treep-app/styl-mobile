import '../../../core/network/api_client.dart';
import '../../../core/network/api_models.dart';

class AppointmentsApi {
  AppointmentsApi(this._client);

  final ApiClient _client;

  Future<List<AppointmentDto>> list({String? status}) async {
    final data = await _client.get(
      '/appointments',
      query: {
        'status': ?status,
      },
    );
    final list = data['appointments'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppointmentDto> getById(String id) async {
    final data = await _client.get('/appointments/$id');
    return AppointmentDto.fromJson(data['appointment'] as Map<String, dynamic>);
  }

  Future<AppointmentDto> create({
    required String shopId,
    required String barberUserId,
    required String scheduledStart,
    String? serviceId,
    String? paymentMethod,
    String? notes,
  }) async {
    final data = await _client.post(
      '/appointments',
      body: {
        'shopId': shopId,
        'barberUserId': barberUserId,
        'scheduledStart': scheduledStart,
        'serviceId': ?serviceId,
        'paymentMethod': ?paymentMethod,
        'notes': ?notes,
      },
    );
    return AppointmentDto.fromJson(data['appointment'] as Map<String, dynamic>);
  }

  Future<AppointmentDto> updateStatus({
    required String id,
    required String status,
  }) async {
    final data = await _client.patch(
      '/appointments/$id/status',
      body: {'status': status},
    );
    return AppointmentDto.fromJson(data['appointment'] as Map<String, dynamic>);
  }

  Future<AppointmentDto> reschedule({
    required String id,
    required String scheduledStart,
  }) async {
    final data = await _client.patch(
      '/appointments/$id/reschedule',
      body: {'scheduledStart': scheduledStart},
    );
    return AppointmentDto.fromJson(data['appointment'] as Map<String, dynamic>);
  }

  Future<PayAppointmentResult> pay({
    required String id,
    required String paymentMethod,
    String? paymentMethodId,
  }) async {
    final data = await _client.post(
      '/appointments/$id/pay',
      body: {
        'paymentMethod': paymentMethod,
        'paymentMethodId': ?paymentMethodId,
      },
    );
    return PayAppointmentResult(
      appointment: AppointmentDto.fromJson(
        data['appointment'] as Map<String, dynamic>,
      ),
      checkout: CheckoutDto.fromJson(
        data['checkout'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  /// After native Payment Sheet succeeds, verify with API and mark PAID.
  Future<AppointmentDto> confirmPayment({
    required String id,
    required String paymentIntentId,
  }) async {
    final data = await _client.post(
      '/appointments/$id/confirm-payment',
      body: {'paymentIntentId': paymentIntentId},
    );
    return AppointmentDto.fromJson(
      data['appointment'] as Map<String, dynamic>,
    );
  }

  Future<AppointmentStatsDto> barberStats() async {
    final data = await _client.get('/barbers/me/appointment-stats');
    return AppointmentStatsDto.fromJson(
      data['stats'] as Map<String, dynamic>,
    );
  }
}

class CheckoutDto {
  const CheckoutDto({
    required this.provider,
    required this.status,
    required this.mode,
    required this.message,
    this.checkoutUrl,
    this.clientSecret,
    this.publishableKey,
    this.providerRef,
  });

  final String provider;
  final String status;
  final String mode;
  final String message;
  final String? checkoutUrl;
  final String? clientSecret;
  final String? publishableKey;
  final String? providerRef;

  bool get requiresAction => status == 'requires_action';

  /// Native Stripe Payment Sheet (preferred on mobile).
  bool get usesPaymentSheet =>
      provider == 'stripe' &&
      clientSecret != null &&
      clientSecret!.isNotEmpty;

  factory CheckoutDto.fromJson(Map<String, dynamic> json) {
    return CheckoutDto(
      provider: json['provider'] as String? ?? 'cash',
      status: json['status'] as String? ?? 'requires_action',
      mode: json['mode'] as String? ?? 'mock',
      message: json['message'] as String? ?? '',
      checkoutUrl: json['checkoutUrl'] as String?,
      clientSecret: json['clientSecret'] as String?,
      publishableKey: json['publishableKey'] as String?,
      providerRef: json['providerRef'] as String?,
    );
  }
}

class PayAppointmentResult {
  const PayAppointmentResult({
    required this.appointment,
    required this.checkout,
  });

  final AppointmentDto appointment;
  final CheckoutDto checkout;
}
