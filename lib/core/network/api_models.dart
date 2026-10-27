import 'dart:convert';

import '../constants/salon_service_catalog.dart';
import '../utils/media_url.dart';

class StylUser {
  const StylUser({
    required this.id,
    required this.phone,
    required this.role,
    this.fullName,
    this.email,
    this.avatarUrl,
    this.isAvailableNow = false,
    this.isOnboarded = true,
    this.isOnline = false,
  });

  final String id;
  final String phone;
  final String role;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final bool isAvailableNow;
  final bool isOnboarded;
  final bool isOnline;

  bool get isBarber => role == 'BARBER';
  bool get isClient => role == 'CLIENT';
  bool get hasEmail => email != null && email!.trim().isNotEmpty;

  factory StylUser.fromJson(Map<String, dynamic> json) {
    return StylUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      fullName: json['fullName'] as String?,
      email: json['email'] as String?,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String?),
      isAvailableNow: json['isAvailableNow'] as bool? ?? false,
      isOnboarded: json['isOnboarded'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'role': role,
    'fullName': fullName,
    'email': email,
    'avatarUrl': avatarUrl,
    'isAvailableNow': isAvailableNow,
    'isOnboarded': isOnboarded,
    'isOnline': isOnline,
  };

  String encode() => jsonEncode(toJson());

  static StylUser? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return StylUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  StylUser copyWith({
    String? fullName,
    String? email,
    String? avatarUrl,
    String? role,
    bool? isAvailableNow,
    bool? isOnboarded,
    bool? isOnline,
  }) {
    return StylUser(
      id: id,
      phone: phone,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isAvailableNow: isAvailableNow ?? this.isAvailableNow,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class ShopDto {
  const ShopDto({
    required this.id,
    required this.name,
    required this.addressLine,
    this.description,
    this.website,
    this.phone,
    this.area,
    this.district,
    this.country,
    this.pincode,
    this.lat,
    this.lng,
    this.imageUrls = const [],
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.distanceKm,
    this.membersCount,
    this.isOwner,
    this.ownerUserId,
    this.hoursLabel,
    this.services = const [],
    this.workingHours = const [],
    this.isVerified = false,
    this.verificationStatus = 'UNVERIFIED',
    this.verificationRequestedAt,
    this.verifiedAt,
  });

  final String id;
  final String name;
  final String addressLine;
  final String? description;
  final String? website;
  final String? phone;
  final String? area;
  final String? district;
  final String? country;
  final String? pincode;
  final double? lat;
  final double? lng;
  final List<String> imageUrls;
  final double ratingAvg;
  final int ratingCount;
  final double? distanceKm;
  final int? membersCount;
  final bool? isOwner;
  final String? ownerUserId;
  final String? hoursLabel;
  final List<ServiceDto> services;
  final List<WorkingHourDto> workingHours;
  final bool isVerified;
  final String verificationStatus;
  final String? verificationRequestedAt;
  final String? verifiedAt;

  /// Cover / hero photo (`imageUrls[0]`).
  String get coverImageUrl => imageUrls.isNotEmpty ? imageUrls.first : '';

  /// Salon logo / profile picture (`imageUrls[1]` when present, else cover).
  String get profileImageUrl =>
      imageUrls.length > 1 ? imageUrls[1] : coverImageUrl;

  /// Preferred customer-facing photo (logo when set, otherwise cover).
  String get imageUrl =>
      profileImageUrl.isNotEmpty ? profileImageUrl : coverImageUrl;

  bool get hasPhoto => imageUrls.isNotEmpty;

  String get distanceLabel {
    if (distanceKm == null) return 'Nearby';
    final mi = distanceKm! * 0.621371;
    return '${mi.toStringAsFixed(1)} miles';
  }

  String get ratingLabel {
    if (ratingCount <= 0) return 'New';
    final stars = ratingAvg.toStringAsFixed(1);
    return '$stars ($ratingCount)';
  }

  String get areaLabel => (area ?? '').trim().isEmpty ? 'Nearby' : area!.trim();

  String get openStatusLabel {
    if (workingHours.isEmpty) {
      return hoursLabel ?? 'Hours not listed';
    }
    final now = DateTime.now();
    final weekday = now.weekday % 7;
    final today = workingHours.where((h) => h.weekday == weekday).toList();
    if (today.isEmpty) return 'Closed today';
    int mins(String t) {
      final parts = t.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return h * 60 + m;
    }

    String format12(String t) {
      final total = mins(t);
      var h = total ~/ 60;
      final m = total % 60;
      final suffix = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return m == 0 ? '$h:00 $suffix' : '$h:${m.toString().padLeft(2, '0')} $suffix';
    }

    final nowMins = now.hour * 60 + now.minute;
    today.sort((a, b) => mins(a.startTime).compareTo(mins(b.startTime)));
    final openNow = today.any((h) {
      final start = mins(h.startTime);
      final end = mins(h.endTime);
      return nowMins >= start && nowMins < end;
    });
    if (openNow) {
      final end = today
          .map((h) => mins(h.endTime))
          .reduce((a, b) => a > b ? a : b);
      final endLabel = format12(
        '${(end ~/ 60).toString().padLeft(2, '0')}:${(end % 60).toString().padLeft(2, '0')}:00',
      );
      return 'Open · Closes $endLabel';
    }
    return 'Closed · Opens ${format12(today.first.startTime)}';
  }

  factory ShopDto.fromJson(Map<String, dynamic> json) {
    return ShopDto(
      id: json['id'] as String,
      name: json['name'] as String,
      addressLine: json['addressLine'] as String? ?? '',
      description: json['description'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      area: json['area'] as String?,
      district: json['district'] as String?,
      country: json['country'] as String?,
      pincode: json['pincode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => resolveMediaUrlRequired(e.toString()))
              .where((u) => u.isNotEmpty)
              .toList() ??
          const [],
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      membersCount: json['membersCount'] as int?,
      isOwner: json['isOwner'] as bool?,
      ownerUserId: json['ownerUserId'] as String?,
      hoursLabel: json['hoursLabel'] as String?,
      services:
          (json['services'] as List<dynamic>?)
              ?.map((e) => ServiceDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      workingHours:
          (json['workingHours'] as List<dynamic>?)
              ?.map((e) => WorkingHourDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isVerified: json['isVerified'] as bool? ??
          (json['verificationStatus'] as String?) == 'VERIFIED',
      verificationStatus:
          json['verificationStatus'] as String? ??
          ((json['isVerified'] as bool?) == true ? 'VERIFIED' : 'UNVERIFIED'),
      verificationRequestedAt: json['verificationRequestedAt'] as String?,
      verifiedAt: json['verifiedAt'] as String?,
    );
  }
}

class ServiceDto {
  const ServiceDto({
    required this.id,
    required this.shopId,
    required this.name,
    required this.priceAmount,
    required this.currency,
    required this.durationMin,
    this.category,
    this.description,
    this.imageUrl,
    this.priceType = 'FIXED',
    this.isActive = true,
    this.assignedBarberIds = const [],
    this.relatedLooks = const [],
  });

  final String id;
  final String shopId;
  final String name;
  final double priceAmount;
  final String currency;
  final int durationMin;
  final String? category;
  final String? description;
  final String? imageUrl;
  final String priceType;
  final bool isActive;
  final List<String> assignedBarberIds;
  final List<String> relatedLooks;

  String get resolvedCategory {
    if (category != null && category!.trim().isNotEmpty) {
      return SalonServiceCatalog.normalizeCategory(category);
    }
    return SalonServiceCatalog.categoryForName(name);
  }

  bool get isFromPrice => priceType.toUpperCase() == 'FROM';

  String get priceLabel {
    final symbol = currency == 'GBP'
        ? '£'
        : currency == 'USD'
        ? '\$'
        : '$currency ';
    final amount = '$symbol${priceAmount.toStringAsFixed(priceAmount % 1 == 0 ? 0 : 2)}';
    return isFromPrice ? 'From $amount' : amount;
  }

  factory ServiceDto.fromJson(Map<String, dynamic> json) {
    return ServiceDto(
      id: json['id'] as String,
      shopId: json['shopId'] as String,
      name: json['name'] as String,
      priceAmount: (json['priceAmount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'GBP',
      durationMin: json['durationMin'] as int? ?? 30,
      category: json['category'] as String?,
      description: json['description'] as String?,
      imageUrl: resolveMediaUrl(json['imageUrl'] as String?),
      priceType: json['priceType'] as String? ?? 'FIXED',
      isActive: json['isActive'] as bool? ?? true,
      assignedBarberIds:
          (json['assignedBarberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      relatedLooks:
          (json['relatedLooks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class WorkingHourDto {
  const WorkingHourDto({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  final int weekday;
  final String startTime;
  final String endTime;

  factory WorkingHourDto.fromJson(Map<String, dynamic> json) {
    return WorkingHourDto(
      weekday: json['weekday'] as int,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }
}

class BarberDto {
  const BarberDto({
    required this.id,
    required this.phone,
    this.fullName,
    this.avatarUrl,
    this.isAvailableNow = false,
    this.isOnboarded = true,
    this.isOnline = false,
    this.hoursLabel,
    this.specialty,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.distanceKm,
    this.shops = const [],
  });

  final String id;
  final String phone;
  final String? fullName;
  final String? avatarUrl;
  final bool isAvailableNow;
  final bool isOnboarded;
  final bool isOnline;
  final String? hoursLabel;
  final String? specialty;
  final double ratingAvg;
  final int ratingCount;
  final double? distanceKm;
  final List<BarberShopRef> shops;

  String get displayName => (fullName ?? '').trim().isEmpty ? 'Professional' : fullName!.trim();

  String get subtitle {
    final shop = shops.isNotEmpty ? shops.first.name : null;
    final spec = (specialty ?? 'Professional').trim();
    if (shop != null && shop.isNotEmpty) return '$spec at $shop';
    return spec;
  }

  String get ratingLabel {
    if (ratingCount <= 0) return 'New';
    return '${ratingAvg.toStringAsFixed(1)} ($ratingCount)';
  }

  factory BarberDto.fromJson(Map<String, dynamic> json) {
    return BarberDto(
      id: json['id'] as String,
      phone: json['phone'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String?),
      isAvailableNow: json['isAvailableNow'] as bool? ?? false,
      isOnboarded: json['isOnboarded'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? false,
      hoursLabel: json['hoursLabel'] as String?,
      specialty: json['specialty'] as String?,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      shops:
          (json['shops'] as List<dynamic>?)
              ?.map((e) => BarberShopRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class BarberShopRef {
  const BarberShopRef({
    required this.id,
    required this.name,
    this.area,
    this.addressLine,
    this.ratingAvg = 0,
    this.imageUrls = const [],
    this.memberRole,
  });

  final String id;
  final String name;
  final String? area;
  final String? addressLine;
  final double ratingAvg;
  final List<String> imageUrls;
  final String? memberRole;

  factory BarberShopRef.fromJson(Map<String, dynamic> json) {
    return BarberShopRef(
      id: json['id'] as String,
      name: json['name'] as String,
      area: json['area'] as String?,
      addressLine: json['addressLine'] as String?,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? 0,
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => resolveMediaUrlRequired(e.toString()))
              .where((u) => u.isNotEmpty)
              .toList() ??
          const [],
      memberRole: json['memberRole'] as String?,
    );
  }
}

class SpecialistDto {
  const SpecialistDto({
    required this.id,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.email,
    this.isAvailableNow = false,
    this.isOnboarded = true,
    this.isOnline = false,
    this.isBusy = false,
    this.isOnShift = false,
    this.presenceLabel = 'Offline',
    this.memberRole,
    this.membershipStatus = 'ACTIVE',
    this.specialty,
    this.receiveBookings = true,
    this.commissionPercent,
    this.hoursLabel,
    this.workingHours = const [],
    this.ratingAvg,
    this.ratingCount,
    this.serviceNames = const [],
    this.nextSlot,
  });

  final String id;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String? email;
  final bool isAvailableNow;
  final bool isOnboarded;
  final bool isOnline;
  final bool isBusy;
  final bool isOnShift;
  final String presenceLabel;
  final String? memberRole;
  final String membershipStatus;
  final String? specialty;
  final bool receiveBookings;
  final double? commissionPercent;
  final String? hoursLabel;
  final List<WorkingHourDto> workingHours;
  final double? ratingAvg;
  final int? ratingCount;
  final List<String> serviceNames;
  final SlotDto? nextSlot;

  String get displayName =>
      (fullName ?? '').trim().isEmpty ? 'Professional' : fullName!.trim();

  factory SpecialistDto.fromJson(Map<String, dynamic> json) {
    return SpecialistDto(
      id: json['id'] as String,
      fullName: json['fullName'] as String?,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String?),
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      isAvailableNow: json['isAvailableNow'] as bool? ?? false,
      isOnboarded: json['isOnboarded'] as bool? ?? true,
      isOnline: json['isOnline'] as bool? ?? false,
      isBusy: json['isBusy'] as bool? ?? false,
      isOnShift: json['isOnShift'] as bool? ?? false,
      presenceLabel:
          json['presenceLabel'] as String? ??
          ((json['isOnboarded'] as bool? ?? true)
              ? ((json['isOnline'] as bool? ?? false) ? 'Online' : 'Offline')
              : 'Unlinked'),
      memberRole: json['memberRole'] as String?,
      membershipStatus: json['membershipStatus'] as String? ?? 'ACTIVE',
      specialty: json['specialty'] as String?,
      receiveBookings: json['receiveBookings'] as bool? ?? true,
      commissionPercent: (json['commissionPercent'] as num?)?.toDouble(),
      hoursLabel: json['hoursLabel'] as String?,
      workingHours:
          (json['workingHours'] as List<dynamic>?)
              ?.map((e) => WorkingHourDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble(),
      ratingCount: (json['ratingCount'] as num?)?.toInt(),
      serviceNames:
          (json['serviceNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((n) => n.trim().isNotEmpty)
              .toList() ??
          const [],
      nextSlot: json['nextSlot'] is Map<String, dynamic>
          ? SlotDto.fromJson(json['nextSlot'] as Map<String, dynamic>)
          : null,
    );
  }

  String get memberRoleLabel => switch (memberRole) {
    'OWNER' => 'Owner',
    'STAFF' => 'Salon barber',
    'FREELANCER' => 'Mobile Barber',
    _ => memberRole ?? 'Member',
  };

  String get roleSpecialtyLabel {
    final specialtyText = specialty?.trim() ?? '';
    if (specialtyText.isEmpty) return memberRoleLabel;
    return '$memberRoleLabel · $specialtyText';
  }

  /// Dart weekday Mon=1..Sun=7 → backend 0=Sun..6=Sat.
  String get todayScheduleLabel {
    final weekday = DateTime.now().weekday % 7;
    final today = workingHours.where((h) => h.weekday == weekday).toList();
    if (today.isEmpty) {
      return workingHours.isEmpty
          ? (hoursLabel ?? 'Hours not set')
          : 'Off today';
    }
    String fmt(String t) => t.length >= 5 ? t.substring(0, 5) : t;
    return today
        .map((h) => '${fmt(h.startTime)}–${fmt(h.endTime)}')
        .join(' · ');
  }

  String get statusCaption {
    if (isBusy) return 'In service';
    return presenceLabel;
  }
}

/// Pending / sent salon team invitation.
class ShopInvitationDto {
  const ShopInvitationDto({
    required this.id,
    required this.shopId,
    required this.channel,
    required this.status,
    required this.inviteLink,
    required this.createdAt,
    this.shopName,
    this.email,
    this.phone,
    this.contact,
    this.personalMessage,
    this.token,
    this.fullName,
    this.avatarUrl,
    this.specialty = 'Barber',
    this.inviteeUserId,
    this.lastSentAt,
    this.expiresAt,
    this.acceptedAt,
  });

  final String id;
  final String shopId;
  final String? shopName;
  final String channel;
  final String? email;
  final String? phone;
  final String? contact;
  final String? personalMessage;
  final String status;
  final String? token;
  final String inviteLink;
  final String? fullName;
  final String? avatarUrl;
  final String specialty;
  final String? inviteeUserId;
  final DateTime? lastSentAt;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    final c = (contact ?? email ?? phone ?? '').trim();
    return c.isEmpty ? 'Professional' : c;
  }

  bool get isEmail => channel == 'EMAIL';
  bool get isPending => status == 'PENDING';

  factory ShopInvitationDto.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return ShopInvitationDto(
      id: json['id'] as String,
      shopId: json['shopId'] as String,
      shopName: json['shopName'] as String?,
      channel: json['channel'] as String? ?? 'EMAIL',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      contact: json['contact'] as String?,
      personalMessage: json['personalMessage'] as String?,
      status: json['status'] as String? ?? 'PENDING',
      token: json['token'] as String?,
      inviteLink: json['inviteLink'] as String? ?? '',
      fullName: json['fullName'] as String?,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String?),
      specialty: json['specialty'] as String? ?? 'Barber',
      inviteeUserId: json['inviteeUserId'] as String?,
      lastSentAt: parse(json['lastSentAt']),
      expiresAt: parse(json['expiresAt']),
      acceptedAt: parse(json['acceptedAt']),
      createdAt: parse(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class SlotDto {
  const SlotDto({
    required this.start,
    required this.end,
    required this.startAt,
    required this.endAt,
    required this.available,
    this.barberUserId,
  });

  final String start;
  final String end;
  final String startAt;
  final String endAt;
  final bool available;
  final String? barberUserId;

  String get label => '$start-$end';

  String get displayLabel {
    final parts = start.split(':');
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? parts[1] : '00';
    final suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $suffix';
  }

  factory SlotDto.fromJson(Map<String, dynamic> json) {
    return SlotDto(
      start: json['start'] as String,
      end: json['end'] as String,
      startAt: json['startAt'] as String,
      endAt: json['endAt'] as String,
      available: json['available'] as bool? ?? true,
      barberUserId: json['barberUserId'] as String?,
    );
  }
}

class AvailabilityShopDto {
  const AvailabilityShopDto({
    required this.shop,
    this.slots = const [],
    this.minPrice = 0,
    this.hasSalon = true,
    this.hasMobile = false,
    this.isVerified = false,
  });

  final ShopDto shop;
  final List<SlotDto> slots;
  final double minPrice;
  final bool hasSalon;
  final bool hasMobile;
  final bool isVerified;

  double get miles => (shop.distanceKm ?? 0) * 0.621371;

  bool get isOpenNow => shop.openStatusLabel.startsWith('Open');

  bool get instantBook => slots.any((s) => s.available);

  factory AvailabilityShopDto.fromJson(Map<String, dynamic> json) {
    final shop = ShopDto.fromJson(json['shop'] as Map<String, dynamic>);
    return AvailabilityShopDto(
      shop: shop,
      slots: (json['slots'] as List<dynamic>? ?? [])
          .map((e) => SlotDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      minPrice: (json['minPrice'] as num?)?.toDouble() ?? 0,
      hasSalon: json['hasSalon'] as bool? ?? true,
      hasMobile: json['hasMobile'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? shop.isVerified,
    );
  }
}

class AppointmentDto {
  const AppointmentDto({
    required this.id,
    required this.status,
    required this.paymentStatus,
    required this.scheduledStart,
    required this.scheduledEnd,
    required this.priceSnapshot,
    this.clientUserId,
    this.barberUserId,
    this.shopId,
    this.paymentMethod,
    this.bookingFeeSnapshot,
    this.notes,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.shopOwnerUserId,
    this.shopArea,
    this.shopImageUrls = const [],
    this.barberName,
    this.barberAvatar,
    this.barberPhone,
    this.barberIsOnline = false,
    this.barberIsOnboarded = true,
    this.barberPresenceLabel,
    this.clientName,
    this.clientAvatar,
    this.clientPhone,
    this.serviceId,
    this.serviceName,
    this.serviceDurationMin,
    this.servicePrice,
    this.currency = 'GBP',
    this.raw,
  });

  final String id;
  final String status;
  final String paymentStatus;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final double priceSnapshot;
  final String? clientUserId;
  final String? barberUserId;
  final String? shopId;
  final String? paymentMethod;
  final double? bookingFeeSnapshot;
  final String? notes;
  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String? shopOwnerUserId;
  final String? shopArea;
  final List<String> shopImageUrls;
  final String? barberName;
  final String? barberAvatar;
  final String? barberPhone;
  final bool barberIsOnline;
  final bool barberIsOnboarded;
  final String? barberPresenceLabel;
  final String? clientName;
  final String? clientAvatar;
  final String? clientPhone;
  final String? serviceId;
  final String? serviceName;
  final int? serviceDurationMin;
  final double? servicePrice;
  final String currency;
  final Map<String, dynamic>? raw;

  String get shopImageUrl {
    if (shopImageUrls.isEmpty) return '';
    // Prefer logo / profile photo when cover + logo are stored.
    if (shopImageUrls.length > 1) return shopImageUrls[1];
    return shopImageUrls.first;
  }

  bool get isOpen => status == 'PENDING' || status == 'CONFIRMED';
  bool get isPending => status == 'PENDING';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isCancelled => status == 'CANCELLED';
  bool get isPaid => paymentStatus.toUpperCase() == 'PAID';
  bool get isUnpaid => !isPaid;

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Pending';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'COMPLETED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Human-readable payment state for the details view.
  String get paymentStatusLabel {
    final method = (paymentMethod ?? '').toUpperCase();
    final paid = isPaid;
    final online = method == 'CARD' || method == 'WALLET' || method == 'PAYPAL';
    if (paid && online) return 'Booking fee paid';
    if (paid && method == 'CASH') return 'Paid at Salon';
    if (paid) return 'Booking fee paid';
    if (bookingFeeSnapshot != null &&
        bookingFeeSnapshot! > 0 &&
        paymentStatus.toUpperCase() == 'UNPAID') {
      return 'Booking fee due';
    }
    if (method == 'CASH') return 'Pay at Salon';
    if (!paid && online) return 'Pay Online';
    return 'Unpaid';
  }

  String get durationLabel {
    final min =
        serviceDurationMin ?? scheduledEnd.difference(scheduledStart).inMinutes;
    if (min <= 0) return '—';
    if (min < 60) return '$min mins';
    final h = min ~/ 60;
    final m = min % 60;
    final hours = h == 1 ? '1 hr' : '$h hrs';
    if (m == 0) return hours;
    return '$hours $m mins';
  }

  String formatMoney(double amount) {
    final symbol = currency == 'GBP'
        ? '£'
        : currency == 'USD'
        ? '\$'
        : '$currency ';
    final whole = amount == amount.roundToDouble();
    return '$symbol${amount.toStringAsFixed(whole ? 0 : 2)}';
  }

  String get totalLabel => formatMoney(priceSnapshot);

  String get servicePriceLabel => formatMoney(servicePrice ?? priceSnapshot);

  String get bookingFeeLabel => formatMoney(bookingFeeSnapshot ?? 0);

  bool get hasBookingFee => (bookingFeeSnapshot ?? 0) > 0;

  bool get bookingFeeOutstanding => hasBookingFee && isUnpaid;

  String get dateLabel {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = scheduledStart.toLocal();
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _hhmm(DateTime d) {
    final local = d.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get startTimeLabel => _hhmm(scheduledStart);
  String get endTimeLabel => _hhmm(scheduledEnd);
  String get timeRangeLabel => '$startTimeLabel – $endTimeLabel';

  String get barberStatusLabel {
    if (!barberIsOnboarded) return 'Unlinked · Offline';
    return barberPresenceLabel ?? (barberIsOnline ? 'Online' : 'Offline');
  }

  factory AppointmentDto.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] as Map<String, dynamic>?;
    final barber = json['barber'] as Map<String, dynamic>?;
    final client = json['client'] as Map<String, dynamic>?;
    final service = json['service'] as Map<String, dynamic>?;
    return AppointmentDto(
      id: json['id'] as String,
      clientUserId: json['clientUserId'] as String?,
      barberUserId: json['barberUserId'] as String?,
      shopId: json['shopId'] as String?,
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String? ?? 'UNPAID',
      scheduledStart: DateTime.parse(json['scheduledStart'] as String),
      scheduledEnd: DateTime.parse(json['scheduledEnd'] as String),
      priceSnapshot: (json['priceSnapshot'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['paymentMethod'] as String?,
      bookingFeeSnapshot: (json['bookingFeeSnapshot'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      shopName: shop?['name'] as String?,
      shopAddress: shop?['addressLine'] as String?,
      shopPhone: shop?['phone'] as String?,
      shopOwnerUserId: shop?['ownerUserId'] as String?,
      shopArea: shop?['area'] as String?,
      shopImageUrls:
          (shop?['imageUrls'] as List<dynamic>?)
              ?.map((e) => resolveMediaUrlRequired(e.toString()))
              .where((u) => u.isNotEmpty)
              .toList() ??
          const [],
      barberName: barber?['fullName'] as String?,
      barberAvatar: resolveMediaUrl(barber?['avatarUrl'] as String?),
      barberPhone: barber?['phone'] as String?,
      barberIsOnline: barber?['isOnline'] as bool? ?? false,
      barberIsOnboarded: barber?['isOnboarded'] as bool? ?? true,
      barberPresenceLabel: barber?['presenceLabel'] as String?,
      clientName: client?['fullName'] as String?,
      clientAvatar: resolveMediaUrl(client?['avatarUrl'] as String?),
      clientPhone: client?['phone'] as String?,
      serviceId: service?['id'] as String?,
      serviceName: service?['name'] as String?,
      serviceDurationMin: service?['durationMin'] as int?,
      servicePrice: (service?['priceAmount'] as num?)?.toDouble(),
      currency: service?['currency'] as String? ?? 'GBP',
      raw: json,
    );
  }
}

class WalletDto {
  const WalletDto({required this.balanceAmount, required this.currency});

  final double balanceAmount;
  final String currency;

  String get balanceLabel {
    final symbol = currency == 'GBP'
        ? '£'
        : currency == 'USD'
        ? '\$'
        : '';
    return '$symbol${balanceAmount.toStringAsFixed(2)}';
  }

  factory WalletDto.fromJson(Map<String, dynamic> json) {
    return WalletDto(
      balanceAmount: (json['balanceAmount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
    );
  }
}

class PaymentMethodDto {
  const PaymentMethodDto({
    required this.id,
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  final String id;
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  factory PaymentMethodDto.fromJson(Map<String, dynamic> json) {
    return PaymentMethodDto(
      id: json['id'] as String,
      brand: json['brand'] as String,
      last4: json['last4'] as String,
      expMonth: json['expMonth'] as int,
      expYear: json['expYear'] as int,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.meta,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? meta;

  bool get unread => readAt == null;

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    return NotificationDto(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

class AppointmentStatsDto {
  const AppointmentStatsDto({
    required this.total,
    required this.opened,
    required this.closed,
  });

  final int total;
  final int opened;
  final int closed;

  factory AppointmentStatsDto.fromJson(Map<String, dynamic> json) {
    return AppointmentStatsDto(
      total: json['total'] as int? ?? 0,
      opened: json['opened'] as int? ?? 0,
      closed: json['closed'] as int? ?? 0,
    );
  }
}
