import '../../../core/network/api_client.dart';
import '../../../core/network/api_models.dart';
import 'looks_catalog.dart';

class CatalogApi {
  CatalogApi(this._client);

  final ApiClient _client;

  Future<List<ShopDto>> listShops({String? q, String? area}) async {
    final data = await _client.get(
      '/shops',
      auth: false,
      query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (area != null && area.isNotEmpty) 'area': area,
      },
    );
    final list = data['shops'] as List<dynamic>? ?? [];
    return list
        .map((e) => ShopDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MarketplaceCatalog> getMarketplace({String? area}) async {
    final data = await _client.get(
      '/catalog',
      auth: false,
      query: {
        if (area != null && area.isNotEmpty) 'area': area,
      },
    );
    return MarketplaceCatalog.fromJson(data);
  }

  Future<CatalogSearchResult> searchCatalog({
    String? q,
    String? area,
  }) async {
    final data = await _client.get(
      '/catalog/search',
      auth: false,
      query: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (area != null && area.isNotEmpty) 'area': area,
      },
    );
    return CatalogSearchResult.fromJson(data);
  }

  Future<CatalogAreas> listAreas() async {
    final data = await _client.get('/catalog/areas', auth: false);
    return CatalogAreas.fromJson(data);
  }

  Future<LookSuggestions> lookSuggestions({
    String? lookId,
    String? categoryId,
  }) async {
    final data = await _client.get(
      '/catalog/look-suggestions',
      auth: false,
      query: {
        if (lookId != null && lookId.isNotEmpty) 'lookId': lookId,
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      },
    );
    return LookSuggestions.fromJson(data);
  }

  Future<AvailabilityResult> listAvailability({
    required String date,
    String? lookId,
    String? area,
  }) async {
    final data = await _client.get(
      '/catalog/availability',
      auth: false,
      query: {
        'date': date,
        if (lookId != null && lookId.isNotEmpty) 'lookId': lookId,
        if (area != null && area.isNotEmpty) 'area': area,
      },
    );
    return AvailabilityResult.fromJson(data);
  }

  Future<ShopDto> getShop(String id) async {
    final data = await _client.get('/shops/$id', auth: false);
    return ShopDto.fromJson(data['shop'] as Map<String, dynamic>);
  }

  Future<List<SpecialistDto>> listSpecialists(
    String shopId, {
    String? date,
    bool includePending = false,
  }) async {
    final data = await _client.get(
      '/shops/$shopId/specialists',
      auth: includePending,
      query: {
        if (date != null && date.isNotEmpty) 'date': date,
        if (includePending) 'includePending': 'true',
      },
    );
    final list = data['specialists'] as List<dynamic>? ?? [];
    return list
        .map((e) => SpecialistDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BarberDto>> listBarbers({String? q}) async {
    final data = await _client.get(
      '/barbers',
      auth: false,
      query: {
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final list = data['barbers'] as List<dynamic>? ?? [];
    return list
        .map((e) => BarberDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SlotDto>> listSlots({
    required String barberId,
    required String date,
  }) async {
    final data = await _client.get(
      '/barbers/$barberId/slots',
      auth: false,
      query: {'date': date},
    );
    final list = data['slots'] as List<dynamic>? ?? [];
    return list
        .map((e) => SlotDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShopDto> createShop(Map<String, dynamic> body) async {
    final data = await _client.post('/shops', body: body);
    return ShopDto.fromJson(data['shop'] as Map<String, dynamic>);
  }

  Future<List<ShopDto>> listMyShops() async {
    final data = await _client.get('/shops/mine');
    final list = data['shops'] as List<dynamic>? ?? [];
    return list
        .map((e) => ShopDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShopDto> updateShop(String shopId, Map<String, dynamic> body) async {
    final data = await _client.patch('/shops/$shopId', body: body);
    return ShopDto.fromJson(data['shop'] as Map<String, dynamic>);
  }

  Future<SalonVerificationDto> getShopVerification(String shopId) async {
    final data = await _client.get('/shops/$shopId/verification');
    return SalonVerificationDto.fromJson(data);
  }

  Future<SalonVerificationDto> requestShopVerification(String shopId) async {
    final data = await _client.post('/shops/$shopId/verification/request');
    return SalonVerificationDto.fromJson(data);
  }

  Future<SpecialistDto> addShopMember({
    required String shopId,
    required String phone,
    String? fullName,
    String? email,
    String? avatarUrl,
    String memberRole = 'STAFF',
    String? specialty,
    double? commissionPercent,
  }) async {
    final data = await _client.post(
      '/shops/$shopId/members',
      body: {
        'phone': phone,
        'memberRole': memberRole,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
        if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
        'commissionPercent': ?commissionPercent,
      },
    );
    return SpecialistDto.fromJson(data['member'] as Map<String, dynamic>);
  }

  Future<void> removeShopMember({
    required String shopId,
    required String barberUserId,
  }) async {
    await _client.delete('/shops/$shopId/members/$barberUserId');
  }

  Future<SpecialistDto> getShopMember({
    required String shopId,
    required String barberUserId,
  }) async {
    final data = await _client.get('/shops/$shopId/members/$barberUserId');
    return SpecialistDto.fromJson(data['member'] as Map<String, dynamic>);
  }

  Future<SpecialistDto> updateShopMemberAccess({
    required String shopId,
    required String barberUserId,
    bool? receiveBookings,
    String? specialty,
  }) async {
    final data = await _client.patch(
      '/shops/$shopId/members/$barberUserId',
      body: {
        'receiveBookings': ?receiveBookings,
        'specialty': ?specialty,
      },
    );
    return SpecialistDto.fromJson(data['member'] as Map<String, dynamic>);
  }

  Future<ShopInvitationDto> createShopInvitation({
    required String shopId,
    required String channel,
    String? email,
    String? phone,
    String? personalMessage,
  }) async {
    final data = await _client.post(
      '/shops/$shopId/invitations',
      body: {
        'channel': channel,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (personalMessage != null && personalMessage.isNotEmpty)
          'personalMessage': personalMessage,
      },
    );
    return ShopInvitationDto.fromJson(
      data['invitation'] as Map<String, dynamic>,
    );
  }

  Future<List<ShopInvitationDto>> listShopInvitations(
    String shopId, {
    String status = 'PENDING',
  }) async {
    final data = await _client.get(
      '/shops/$shopId/invitations',
      query: {'status': status},
    );
    final list = data['invitations'] as List<dynamic>? ?? [];
    return list
        .map((e) => ShopInvitationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShopInvitationDto> getShopInvitation({
    required String shopId,
    required String invitationId,
  }) async {
    final data = await _client.get(
      '/shops/$shopId/invitations/$invitationId',
    );
    return ShopInvitationDto.fromJson(
      data['invitation'] as Map<String, dynamic>,
    );
  }

  Future<ShopInvitationDto> resendShopInvitation({
    required String shopId,
    required String invitationId,
  }) async {
    final data = await _client.post(
      '/shops/$shopId/invitations/$invitationId/resend',
    );
    return ShopInvitationDto.fromJson(
      data['invitation'] as Map<String, dynamic>,
    );
  }

  Future<void> cancelShopInvitation({
    required String shopId,
    required String invitationId,
  }) async {
    await _client.delete('/shops/$shopId/invitations/$invitationId');
  }

  Future<List<AppointmentDto>> listMemberAppointments({
    required String shopId,
    required String barberUserId,
  }) async {
    final data = await _client.get(
      '/shops/$shopId/members/$barberUserId/appointments',
    );
    final list = data['appointments'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> linkShop(String shopId) async {
    await _client.post('/shops/$shopId/link');
  }

  Future<SpecialistDto> approveShopMember({
    required String shopId,
    required String barberUserId,
  }) async {
    final data = await _client.post(
      '/shops/$shopId/members/$barberUserId/approve',
    );
    return SpecialistDto.fromJson(data['member'] as Map<String, dynamic>);
  }

  Future<void> rejectShopMember({
    required String shopId,
    required String barberUserId,
  }) async {
    await _client.post('/shops/$shopId/members/$barberUserId/reject');
  }

  Future<List<WorkingHourDto>> listMyWorkingHours() async {
    final data = await _client.get('/me/working-hours');
    final list = data['hours'] as List<dynamic>? ?? [];
    return list
        .map((e) => WorkingHourDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ServiceDto>> listServices(
    String shopId, {
    bool includeInactive = false,
  }) async {
    final data = await _client.get(
      '/shops/$shopId/services',
      auth: includeInactive,
      query: {
        if (includeInactive) 'includeInactive': 'true',
      },
    );
    final list = data['services'] as List<dynamic>? ?? [];
    return list
        .map((e) => ServiceDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceDto> createService(
    String shopId, {
    required String name,
    required double priceAmount,
    String currency = 'GBP',
    int durationMin = 30,
    String? category,
    String? description,
    String? imageUrl,
    String priceType = 'FIXED',
    List<String>? assignedBarberIds,
    List<String>? relatedLooks,
  }) async {
    final data = await _client.post(
      '/shops/$shopId/services',
      body: {
        'name': name,
        'priceAmount': priceAmount,
        'currency': currency,
        'durationMin': durationMin,
        if (category != null && category.isNotEmpty) 'category': category,
        'description': ?description,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'priceType': priceType,
        'assignedBarberIds': ?assignedBarberIds,
        'relatedLooks': ?relatedLooks,
      },
    );
    return ServiceDto.fromJson(data['service'] as Map<String, dynamic>);
  }

  Future<ServiceDto> updateService(
    String shopId,
    String serviceId, {
    String? name,
    double? priceAmount,
    String? currency,
    int? durationMin,
    String? category,
    String? description,
    String? imageUrl,
    String? priceType,
    bool? isActive,
    List<String>? assignedBarberIds,
    List<String>? relatedLooks,
  }) async {
    final data = await _client.patch(
      '/shops/$shopId/services/$serviceId',
      body: {
        'name': ?name,
        'priceAmount': ?priceAmount,
        'currency': ?currency,
        'durationMin': ?durationMin,
        'category': ?category,
        'description': ?description,
        'imageUrl': ?imageUrl,
        'priceType': ?priceType,
        'isActive': ?isActive,
        'assignedBarberIds': ?assignedBarberIds,
        'relatedLooks': ?relatedLooks,
      },
    );
    return ServiceDto.fromJson(data['service'] as Map<String, dynamic>);
  }

  Future<void> deleteService(String shopId, String serviceId) async {
    await _client.delete('/shops/$shopId/services/$serviceId');
  }

  Future<void> replaceWorkingHours(
    List<Map<String, dynamic>> hours,
  ) async {
    await _client.put('/me/working-hours', body: {'hours': hours});
  }
}

class MarketplaceCatalog {
  const MarketplaceCatalog({
    required this.shops,
    required this.looks,
    required this.categories,
    this.professionals = const [],
    this.areas = const [],
    this.popularAreas = const [],
  });

  final List<ShopDto> shops;
  final List<StyleLook> looks;
  final List<LookCategory> categories;
  final List<BarberDto> professionals;
  final List<CatalogArea> areas;
  final List<CatalogArea> popularAreas;

  factory MarketplaceCatalog.fromJson(Map<String, dynamic> data) {
    return MarketplaceCatalog(
      shops: (data['shops'] as List<dynamic>? ?? [])
          .map((e) => ShopDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      looks: (data['looks'] as List<dynamic>? ?? [])
          .map((e) => StyleLook.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (data['categories'] as List<dynamic>? ?? [])
          .map((e) => LookCategory.fromApi(e as Map<String, dynamic>))
          .toList(),
      professionals: (data['professionals'] as List<dynamic>? ?? [])
          .map((e) => BarberDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      areas: (data['areas'] as List<dynamic>? ?? [])
          .map((e) => CatalogArea.fromJson(e as Map<String, dynamic>))
          .toList(),
      popularAreas: (data['popularAreas'] as List<dynamic>? ?? [])
          .map((e) => CatalogArea.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CatalogSearchResult {
  const CatalogSearchResult({
    required this.shops,
    required this.professionals,
    required this.looks,
    this.topShop,
    this.query = '',
  });

  final ShopDto? topShop;
  final List<ShopDto> shops;
  final List<BarberDto> professionals;
  final List<StyleLook> looks;
  final String query;

  factory CatalogSearchResult.fromJson(Map<String, dynamic> data) {
    return CatalogSearchResult(
      topShop: data['topShop'] is Map<String, dynamic>
          ? ShopDto.fromJson(data['topShop'] as Map<String, dynamic>)
          : null,
      shops: (data['shops'] as List<dynamic>? ?? [])
          .map((e) => ShopDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      professionals: (data['professionals'] as List<dynamic>? ?? [])
          .map((e) => BarberDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      looks: (data['looks'] as List<dynamic>? ?? [])
          .map((e) => StyleLook.fromJson(e as Map<String, dynamic>))
          .toList(),
      query: data['query'] as String? ?? '',
    );
  }
}

class CatalogAreas {
  const CatalogAreas({
    required this.areas,
    required this.popularAreas,
  });

  final List<CatalogArea> areas;
  final List<CatalogArea> popularAreas;

  factory CatalogAreas.fromJson(Map<String, dynamic> data) {
    return CatalogAreas(
      areas: (data['areas'] as List<dynamic>? ?? [])
          .map((e) => CatalogArea.fromJson(e as Map<String, dynamic>))
          .toList(),
      popularAreas: (data['popularAreas'] as List<dynamic>? ?? [])
          .map((e) => CatalogArea.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CatalogArea {
  const CatalogArea({
    required this.name,
    this.lat,
    this.lng,
    this.shopCount = 0,
  });

  final String name;
  final double? lat;
  final double? lng;
  final int shopCount;

  factory CatalogArea.fromJson(Map<String, dynamic> json) {
    return CatalogArea(
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      shopCount: json['shopCount'] as int? ?? 0,
    );
  }
}

class LookSuggestions {
  const LookSuggestions({
    this.suggested,
    this.alternatives = const [],
    this.matchingShopCount = 0,
  });

  final StyleLook? suggested;
  final List<StyleLook> alternatives;
  final int matchingShopCount;

  factory LookSuggestions.fromJson(Map<String, dynamic> data) {
    return LookSuggestions(
      suggested: data['suggested'] is Map<String, dynamic>
          ? StyleLook.fromJson(data['suggested'] as Map<String, dynamic>)
          : null,
      alternatives: (data['alternatives'] as List<dynamic>? ?? [])
          .map((e) => StyleLook.fromJson(e as Map<String, dynamic>))
          .toList(),
      matchingShopCount: data['matchingShopCount'] as int? ?? 0,
    );
  }
}

class AvailabilityResult {
  const AvailabilityResult({
    required this.date,
    required this.shops,
    this.lookId,
    this.lookName,
  });

  final String date;
  final String? lookId;
  final String? lookName;
  final List<AvailabilityShopDto> shops;

  factory AvailabilityResult.fromJson(Map<String, dynamic> data) {
    return AvailabilityResult(
      date: data['date'] as String? ?? '',
      lookId: data['lookId'] as String?,
      lookName: data['lookName'] as String?,
      shops: (data['shops'] as List<dynamic>? ?? [])
          .map((e) => AvailabilityShopDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SalonVerificationChecklistItem {
  const SalonVerificationChecklistItem({
    required this.id,
    required this.label,
    required this.met,
  });

  final String id;
  final String label;
  final bool met;

  factory SalonVerificationChecklistItem.fromJson(Map<String, dynamic> json) {
    return SalonVerificationChecklistItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      met: json['met'] as bool? ?? false,
    );
  }
}

class SalonVerificationDto {
  const SalonVerificationDto({
    required this.shop,
    this.checklist = const [],
    this.message,
  });

  final ShopDto shop;
  final List<SalonVerificationChecklistItem> checklist;
  final String? message;

  bool get isVerified => shop.isVerified;
  bool get isPending => shop.verificationStatus == 'PENDING';
  bool get allChecksMet =>
      checklist.isNotEmpty && checklist.every((c) => c.met);

  factory SalonVerificationDto.fromJson(Map<String, dynamic> data) {
    return SalonVerificationDto(
      shop: ShopDto.fromJson(data['shop'] as Map<String, dynamic>),
      checklist: (data['checklist'] as List<dynamic>? ?? [])
          .map(
            (e) => SalonVerificationChecklistItem.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
      message: data['message'] as String?,
    );
  }
}
