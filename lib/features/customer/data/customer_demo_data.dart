import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';

enum ProviderKind { freelancer, shop }

class SalonPreview {
  const SalonPreview({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.rating,
    required this.distance,
    required this.address,
    this.kind = ProviderKind.shop,
    this.bio =
        'Lorem Ipsum is simply dummy text of the printing and typesetting industry.',
    this.imageUrl,
    this.shopId,
    this.barberUserId,
    this.isOnline = false,
    this.isOnboarded = true,
  });

  final String id;
  final String name;
  final String subtitle;
  final double rating;
  final String distance;
  final String address;
  final ProviderKind kind;
  final String bio;
  final String? imageUrl;
  /// Shop used for booking (required for freelancers with a membership).
  final String? shopId;
  final String? barberUserId;
  final bool isOnline;
  final bool isOnboarded;

  String get bookingShopId => shopId ?? id;

  ProviderDetailArgs toDetailArgs() {
    return ProviderDetailArgs(
      shopId: bookingShopId,
      name: name,
      subtitle: subtitle,
      rating: rating,
      distance: distance,
      address: address,
      imageUrl: imageUrl,
      description: bio,
      barberUserId: barberUserId,
    );
  }

  factory SalonPreview.fromShop(ShopDto shop) {
    return SalonPreview(
      id: shop.id,
      shopId: shop.id,
      name: shop.name,
      subtitle: shop.area?.isNotEmpty == true ? shop.area! : 'Salon',
      rating: shop.ratingAvg,
      distance: shop.distanceLabel,
      address: shop.addressLine,
      kind: ProviderKind.shop,
      bio: shop.description ??
          'Lorem Ipsum is simply dummy text of the printing and typesetting industry.',
      imageUrl: shop.imageUrl,
    );
  }

  factory SalonPreview.fromBarber(BarberDto barber) {
    final shop = barber.shops.isNotEmpty ? barber.shops.first : null;
    return SalonPreview(
      id: barber.id,
      barberUserId: barber.id,
      shopId: shop?.id,
      name: barber.fullName ?? 'Barber',
      subtitle: shop != null ? 'Freelance Barber' : 'Hair specialist',
      rating: shop?.ratingAvg ?? 4.5,
      distance: 'Nearby',
      address: shop?.addressLine ?? shop?.area ?? 'Address on request',
      kind: ProviderKind.freelancer,
      imageUrl: barber.avatarUrl ??
          (shop != null && shop.imageUrls.isNotEmpty
              ? shop.imageUrls.first
              : null),
      isOnline: barber.isOnline,
      isOnboarded: barber.isOnboarded,
    );
  }
}

enum BarberListMode { freelancers, shops }

class BarberListArgs {
  const BarberListArgs({required this.mode});

  final BarberListMode mode;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.dateLabel,
    required this.timeLabel,
    required this.createdAt,
    this.type = '',
    this.unread = false,
    this.showActions = false,
    this.appointmentId,
    this.shopId,
  });

  final String id;
  final String title;
  final String subtitle;
  final String dateLabel;
  final String timeLabel;
  final DateTime createdAt;
  final String type;
  final bool unread;
  final bool showActions;

  /// Linked booking when backend sends `meta.appointmentId`.
  final String? appointmentId;
  final String? shopId;

  bool get hasAppointment =>
      appointmentId != null && appointmentId!.trim().isNotEmpty;

  bool get isJoinRequest => type == 'SHOP_JOIN_REQUEST';
  bool get isJoinDecision =>
      type == 'SHOP_JOIN_APPROVED' || type == 'SHOP_JOIN_REJECTED';

  factory AppNotification.fromDto(NotificationDto n) {
    final local = n.createdAt.toLocal();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final dateLabel =
        '${months[local.month - 1]} ${local.day},${local.year}';
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final rawId = n.meta?['appointmentId'];
    final appointmentId = rawId is String && rawId.trim().isNotEmpty
        ? rawId.trim()
        : null;
    final rawShop = n.meta?['shopId'];
    final shopId = rawShop is String && rawShop.trim().isNotEmpty
        ? rawShop.trim()
        : null;
    return AppNotification(
      id: n.id,
      title: n.title,
      subtitle: n.body,
      dateLabel: dateLabel,
      timeLabel: '$hh:$mm',
      createdAt: local,
      type: n.type,
      unread: n.unread,
      showActions: n.type.contains('REQUEST'),
      appointmentId: appointmentId,
      shopId: shopId,
    );
  }
}
