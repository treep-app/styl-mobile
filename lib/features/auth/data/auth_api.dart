import '../../../core/network/api_client.dart';
import '../../../core/network/api_models.dart';
import '../../../core/utils/phone_utils.dart';

class AuthApi {
  AuthApi(this._client);

  final ApiClient _client;

  Future<SendOtpResult> sendOtp({
    required String phone,
    required String role,
  }) async {
    final data = await _client.post(
      '/auth/send-otp',
      auth: false,
      body: {
        'phone': toE164(phone),
        'role': role,
      },
    );
    return SendOtpResult(
      phone: data['phone'] as String? ?? toE164(phone),
      expiresInSeconds: data['expiresInSeconds'] as int? ?? 300,
      delivery: data['delivery'] as String? ?? 'sms',
      devCode: data['devCode'] as String?,
    );
  }

  Future<AuthSessionResult> verifyOtp({
    required String phone,
    required String code,
    String? fullName,
    String? password,
    String? role,
  }) async {
    final data = await _client.post(
      '/auth/verify-otp',
      auth: false,
      body: {
        'phone': toE164(phone),
        'code': code,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        if (password != null && password.isNotEmpty) 'password': password,
        'role': ?role,
      },
    );
    return AuthSessionResult.fromJson(data);
  }

  Future<AuthSessionResult> login({
    required String phone,
    required String password,
    String? role,
  }) async {
    final data = await _client.post(
      '/auth/login',
      auth: false,
      body: {
        'phone': toE164(phone),
        'password': password,
        'role': ?role,
      },
    );
    return AuthSessionResult.fromJson(data);
  }

  Future<AuthSessionResult> refresh(String refreshToken) async {
    final data = await _client.post(
      '/auth/refresh',
      auth: false,
      body: {'refreshToken': refreshToken},
    );
    return AuthSessionResult.fromJson(data);
  }

  Future<void> logout({String? refreshToken}) async {
    await _client.post(
      '/auth/logout',
      body: {
        'refreshToken': ?refreshToken,
      },
    );
  }

  Future<StylUser> me() async {
    final data = await _client.get('/me');
    return StylUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<StylUser> updateMe({
    String? fullName,
    String? email,
    String? avatarUrl,
  }) async {
    final data = await _client.patch(
      '/me',
      body: {
        'fullName': ?fullName,
        'email': ?email,
        'avatarUrl': ?avatarUrl,
      },
    );
    return StylUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<StylUser> setAvailability(bool isAvailableNow) async {
    final data = await _client.patch(
      '/me/availability',
      body: {'isAvailableNow': isAvailableNow},
    );
    return StylUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AuthSessionResult> completeOnboarding({
    required String role,
    String? providerType,
  }) async {
    final data = await _client.post(
      '/auth/complete-onboarding',
      body: {
        'role': role,
        'providerType': ?providerType,
      },
    );
    return AuthSessionResult.fromJson(data);
  }
}

class SendOtpResult {
  const SendOtpResult({
    required this.phone,
    required this.expiresInSeconds,
    required this.delivery,
    this.devCode,
  });

  final String phone;
  final int expiresInSeconds;
  final String delivery;
  final String? devCode;
}

class AuthSessionResult {
  const AuthSessionResult({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.isNewUser,
  });

  final StylUser user;
  final String accessToken;
  final String refreshToken;
  final bool isNewUser;

  factory AuthSessionResult.fromJson(Map<String, dynamic> data) {
    return AuthSessionResult(
      user: StylUser.fromJson(data['user'] as Map<String, dynamic>),
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      isNewUser: data['isNewUser'] as bool? ?? false,
    );
  }
}
