import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../network/api_models.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/data/uploads_api.dart';
import '../../features/customer/data/appointments_api.dart';
import '../../features/customer/data/catalog_api.dart';
import '../../features/customer/data/looks_catalog.dart';
import '../../features/customer/data/notifications_api.dart';
import '../../features/customer/data/payments_api.dart';
import 'session_store.dart';

/// App-wide auth + API façade.
class AuthController extends ChangeNotifier {
  AuthController({SessionStore? store}) : _store = store ?? SessionStore() {
    _client = ApiClient(
      readAccessToken: _store.readAccessToken,
      tryRefresh: refreshSession,
    );
    authApi = AuthApi(_client);
    uploadsApi = UploadsApi(_client);
    catalogApi = CatalogApi(_client);
    appointmentsApi = AppointmentsApi(_client);
    paymentsApi = PaymentsApi(_client);
    notificationsApi = NotificationsApi(_client);
  }

  final SessionStore _store;
  late final ApiClient _client;

  late final AuthApi authApi;
  late final UploadsApi uploadsApi;
  late final CatalogApi catalogApi;
  late final AppointmentsApi appointmentsApi;
  late final PaymentsApi paymentsApi;
  late final NotificationsApi notificationsApi;

  StylUser? user;
  bool bootstrapped = false;
  bool busy = false;
  /// Suppresses the “add email” sheet for the rest of this app session.
  bool emailPromptDismissedThisSession = false;

  List<ShopDto> marketplaceShops = const [];
  List<StyleLook> marketplaceLooks = const [];
  List<LookCategory> marketplaceCategories = const [];
  List<BarberDto> marketplaceProfessionals = const [];
  List<CatalogArea> marketplaceAreas = const [];
  List<CatalogArea> popularAreas = const [];
  var marketplaceLoading = false;
  String? marketplaceError;
  String marketplaceArea = '';

  bool get isLoggedIn => user != null;
  bool get needsEmail => user != null && !user!.hasEmail;

  StyleLook? lookById(String id) {
    for (final look in marketplaceLooks) {
      if (look.id == id) return look;
    }
    return null;
  }

  LookCategory categoryById(String id) {
    for (final c in marketplaceCategories) {
      if (c.id == id) return c;
    }
    return LooksCatalog.taxonomyById(id);
  }

  List<StyleLook> looksForCategory(String categoryId, {String? query}) {
    final q = query?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      return marketplaceLooks
          .where(
            (l) =>
                l.name.toLowerCase().contains(q) ||
                l.description.toLowerCase().contains(q),
          )
          .toList();
    }
    var list = marketplaceLooks
        .where((l) => l.categoryId == categoryId)
        .toList();
    if (categoryId == 'more' && list.isEmpty) {
      list = [...marketplaceLooks];
    }
    return list;
  }

  List<ShopDto> shopsForLook(StyleLook look) {
    if (look.shopIds.isEmpty) return marketplaceShops;
    final ids = look.shopIds.toSet();
    return marketplaceShops.where((s) => ids.contains(s.id)).toList();
  }

  Future<void> loadMarketplace({bool force = false, String? area}) async {
    if (marketplaceLoading) return;
    if (!force && marketplaceLooks.isNotEmpty && (area == null || area == marketplaceArea)) {
      return;
    }
    marketplaceLoading = true;
    marketplaceError = null;
    notifyListeners();
    try {
      final data = await catalogApi.getMarketplace(
        area: area ?? (marketplaceArea.isEmpty ? null : marketplaceArea),
      );
      marketplaceShops = data.shops;
      marketplaceLooks = data.looks;
      marketplaceCategories = data.categories;
      marketplaceProfessionals = data.professionals;
      marketplaceAreas = data.areas;
      popularAreas = data.popularAreas;
      if (area != null) marketplaceArea = area;
      marketplaceError = null;
    } catch (e) {
      marketplaceError = e.toString();
    } finally {
      marketplaceLoading = false;
      notifyListeners();
    }
  }

  Future<CatalogSearchResult> searchMarketplace({
    String? q,
    String? area,
  }) {
    return catalogApi.searchCatalog(
      q: q,
      area: area ?? (marketplaceArea.isEmpty ? null : marketplaceArea),
    );
  }

  Future<void> bootstrap() async {
    final cached = StylUser.tryDecode(await _store.readUserJson());
    final token = await _store.readAccessToken();
    if (cached != null && token != null) {
      user = cached;
      try {
        user = await authApi.me();
        await _store.saveUserJson(user!.encode());
      } catch (_) {
        final refreshed = await refreshSession();
        if (!refreshed) {
          await clearSession();
        }
      }
    }
    bootstrapped = true;
    notifyListeners();
    unawaited(loadMarketplace());
  }

  Future<bool> refreshSession() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null) return false;
    try {
      final result = await authApi.refresh(refresh);
      await _persist(result);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<SendOtpResult> sendOtp({
    required String phone,
    required String role,
  }) {
    return authApi.sendOtp(phone: phone, role: role);
  }

  Future<AuthSessionResult> login({
    required String phone,
    required String password,
    String? role,
  }) async {
    final result = await authApi.login(
      phone: phone,
      password: password,
      role: role,
    );
    await _persist(result);
    return result;
  }

  Future<AuthSessionResult> verifyOtp({
    required String phone,
    required String code,
    String? fullName,
    String? password,
    String? role,
  }) async {
    final result = await authApi.verifyOtp(
      phone: phone,
      code: code,
      fullName: fullName,
      password: password,
      role: role,
    );
    await _persist(result);
    return result;
  }

  Future<void> logout() async {
    try {
      final refresh = await _store.readRefreshToken();
      await authApi.logout(refreshToken: refresh);
    } catch (_) {
      // best-effort
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    user = null;
    emailPromptDismissedThisSession = false;
    marketplaceShops = const [];
    marketplaceLooks = const [];
    marketplaceCategories = const [];
    marketplaceProfessionals = const [];
    marketplaceAreas = const [];
    popularAreas = const [];
    marketplaceArea = '';
    await _store.clear();
    notifyListeners();
  }

  Future<void> reloadMe() async {
    user = await authApi.me();
    await _store.saveUserJson(user!.encode());
    notifyListeners();
  }

  Future<void> updateProfile({String? fullName, String? email}) async {
    // Email can only be set once — never overwrite an existing one from the client.
    final canSetEmail =
        email != null && (user == null || !user!.hasEmail);
    user = await authApi.updateMe(
      fullName: fullName,
      email: canSetEmail ? email : null,
    );
    await _store.saveUserJson(user!.encode());
    notifyListeners();
  }

  void dismissEmailPromptForSession() {
    emailPromptDismissedThisSession = true;
    notifyListeners();
  }

  Future<void> setAvailability(bool isAvailableNow) async {
    user = await authApi.setAvailability(isAvailableNow);
    await _store.saveUserJson(user!.encode());
    notifyListeners();
  }

  Future<AuthSessionResult> completeOnboarding({
    required String role,
    String? providerType,
  }) async {
    final result = await authApi.completeOnboarding(
      role: role,
      providerType: providerType,
    );
    await _persist(result);
    return result;
  }

  Future<void> _persist(AuthSessionResult result) async {
    user = result.user;
    emailPromptDismissedThisSession = false;
    await _store.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _store.saveUserJson(result.user.encode());
    notifyListeners();
  }
}
