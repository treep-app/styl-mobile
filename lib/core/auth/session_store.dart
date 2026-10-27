import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _accessKey = 'styl_access_token';
  static const _refreshKey = 'styl_refresh_token';
  static const _userJsonKey = 'styl_user_json';
  static const _onboardingKey = 'styl_onboarding_done';
  static const _notificationsKey = 'styl_notifications_enabled';
  static const _providerSetupStageKey = 'styl_provider_setup_stage';
  static const _providerSetupShopIdKey = 'styl_provider_setup_shop_id';
  static const _ownerOnboardingDoneKey = 'styl_owner_onboarding_done';
  static const _preferCustomerViewKey = 'styl_prefer_customer_view';
  static const _savedLooksKey = 'styl_saved_look_ids';
  static const _savedShopsKey = 'styl_saved_shop_ids';
  static const _savedBarbersKey = 'styl_saved_barber_ids';
  static const _reviewsKey = 'styl_local_reviews';
  static const _locationKey = 'styl_customer_location';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, accessToken);
    await prefs.setString(_refreshKey, refreshToken);
  }

  Future<void> saveUserJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userJsonKey, json);
  }

  Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  Future<String?> readUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userJsonKey);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Provider onboarding resume stages:
  /// `provider_type` → `salon_profile` → `services` → `opening_hours` →
  /// `team` → `booking_settings` → cleared when done.
  Future<String?> readProviderSetupStage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerSetupStageKey);
  }

  Future<void> setProviderSetupStage(String? stage) async {
    final prefs = await SharedPreferences.getInstance();
    if (stage == null || stage.isEmpty) {
      await prefs.remove(_providerSetupStageKey);
    } else {
      await prefs.setString(_providerSetupStageKey, stage);
    }
  }

  Future<String?> readProviderSetupShopId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_providerSetupShopIdKey);
  }

  Future<void> setProviderSetupShopId(String? shopId) async {
    final prefs = await SharedPreferences.getInstance();
    if (shopId == null || shopId.isEmpty) {
      await prefs.remove(_providerSetupShopIdKey);
    } else {
      await prefs.setString(_providerSetupShopIdKey, shopId);
    }
  }

  Future<void> clearProviderSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerSetupStageKey);
    await prefs.remove(_providerSetupShopIdKey);
  }

  Future<bool> readOwnerOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ownerOnboardingDoneKey) ?? false;
  }

  Future<void> setOwnerOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ownerOnboardingDoneKey, value);
  }

  Future<bool> readPreferCustomerView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_preferCustomerViewKey) ?? false;
  }

  Future<void> setPreferCustomerView(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferCustomerViewKey, value);
  }

  static const _bookingInstantKey = 'styl_booking_instant_confirm';
  static const _bookingSameDayKey = 'styl_booking_same_day';
  static const _bookingMinNoticeKey = 'styl_booking_min_notice';
  static const _bookingMaxAdvanceKey = 'styl_booking_max_advance';
  static const _bookingCancelPolicyKey = 'styl_booking_cancel_policy';
  static const _bookingDepositKey = 'styl_booking_deposit';

  Future<bool> readBookingInstantConfirm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bookingInstantKey) ?? true;
  }

  Future<void> setBookingInstantConfirm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bookingInstantKey, value);
  }

  Future<bool> readBookingSameDayAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bookingSameDayKey) ?? true;
  }

  Future<void> setBookingSameDayAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bookingSameDayKey, value);
  }

  Future<String> readBookingMinNotice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bookingMinNoticeKey) ?? '2 hours';
  }

  Future<void> setBookingMinNotice(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookingMinNoticeKey, value);
  }

  Future<String> readBookingMaxAdvance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bookingMaxAdvanceKey) ?? '60 days';
  }

  Future<void> setBookingMaxAdvance(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookingMaxAdvanceKey, value);
  }

  Future<String> readBookingCancelPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bookingCancelPolicyKey) ?? '24 hours';
  }

  Future<void> setBookingCancelPolicy(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookingCancelPolicyKey, value);
  }

  Future<String> readBookingDeposit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bookingDepositKey) ?? 'No deposit';
  }

  Future<void> setBookingDeposit(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookingDepositKey, value);
  }

  Future<bool> readNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, enabled);
  }

  Future<List<String>> readSavedLookIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedLooksKey) ?? const [];
  }

  Future<bool> isLookSaved(String id) async {
    final ids = await readSavedLookIds();
    return ids.contains(id);
  }

  Future<void> setLookSaved(String id, bool saved) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [...(prefs.getStringList(_savedLooksKey) ?? <String>[])];
    if (saved) {
      if (!ids.contains(id)) ids.add(id);
    } else {
      ids.remove(id);
    }
    await prefs.setStringList(_savedLooksKey, ids);
  }

  Future<List<String>> readSavedShopIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedShopsKey) ?? const [];
  }

  Future<bool> isShopSaved(String id) async {
    final ids = await readSavedShopIds();
    return ids.contains(id);
  }

  Future<void> setShopSaved(String id, bool saved) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [...(prefs.getStringList(_savedShopsKey) ?? <String>[])];
    if (saved) {
      if (!ids.contains(id)) ids.add(id);
    } else {
      ids.remove(id);
    }
    await prefs.setStringList(_savedShopsKey, ids);
  }

  Future<List<String>> readSavedBarberIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedBarbersKey) ?? const [];
  }

  Future<bool> isBarberSaved(String id) async {
    final ids = await readSavedBarberIds();
    return ids.contains(id);
  }

  Future<void> setBarberSaved(String id, bool saved) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [...(prefs.getStringList(_savedBarbersKey) ?? <String>[])];
    if (saved) {
      if (!ids.contains(id)) ids.add(id);
    } else {
      ids.remove(id);
    }
    await prefs.setStringList(_savedBarbersKey, ids);
  }

  Future<bool> hasReview(String appointmentId) async {
    final reviews = await readReviews();
    return reviews.any((r) => r['appointmentId'] == appointmentId);
  }

  Future<List<Map<String, dynamic>>> readReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_reviewsKey);
    if (raw == null || raw.isEmpty) return const [];
    final list = jsonDecode(raw) as List<dynamic>? ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveReview({
    required String appointmentId,
    required int rating,
    required String matchPhoto,
    required String wouldReturn,
    required String comment,
    String? photoPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final reviews = [...await readReviews()];
    reviews.removeWhere((r) => r['appointmentId'] == appointmentId);
    reviews.add({
      'appointmentId': appointmentId,
      'rating': rating,
      'matchPhoto': matchPhoto,
      'wouldReturn': wouldReturn,
      'comment': comment,
      'photoPath': photoPath,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_reviewsKey, jsonEncode(reviews));
  }

  Future<String> readLocationLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_locationKey) ?? '';
  }

  Future<void> setLocationLabel(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, label);
    await addRecentLocation(label);
  }

  static const _recentLocationsKey = 'styl_recent_locations';
  static const _defaultRecents = [
    'Kingston upon Thames',
    'Surbiton',
    'New Malden',
    'Raynes Park',
    'SW15',
  ];

  Future<List<String>> readRecentLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_recentLocationsKey);
    if (stored == null || stored.isEmpty) return _defaultRecents;
    return stored;
  }

  Future<void> addRecentLocation(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty || trimmed == 'Current location') return;
    final prefs = await SharedPreferences.getInstance();
    final next = [
      trimmed,
      ...((prefs.getStringList(_recentLocationsKey) ?? _defaultRecents)
          .where((e) => e != trimmed)),
    ].take(8).toList();
    await prefs.setStringList(_recentLocationsKey, next);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove(_userJsonKey);
    await prefs.remove(_providerSetupStageKey);
    await prefs.remove(_providerSetupShopIdKey);
    await prefs.remove(_preferCustomerViewKey);
    await prefs.remove(_ownerOnboardingDoneKey);
    // Keep marketing onboarding + notification prefs for returning users.
  }
}
