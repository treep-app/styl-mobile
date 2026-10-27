import '../../../core/network/api_models.dart';

enum ProviderApptKind { opened, completed, cancelled }

class ProviderAppointment {
  const ProviderAppointment({
    required this.id,
    required this.clientName,
    required this.timeRange,
    required this.kind,
    this.avatarUrl,
    required this.dto,
  });

  final String id;
  final String clientName;
  final String timeRange;
  final ProviderApptKind kind;
  final String? avatarUrl;
  final AppointmentDto dto;

  bool get isClosed =>
      kind == ProviderApptKind.completed || kind == ProviderApptKind.cancelled;

  factory ProviderAppointment.fromDto(AppointmentDto a) {
    final start = a.scheduledStart.toLocal();
    final end = a.scheduledEnd.toLocal();
    String fmt(DateTime d) {
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    final kind = switch (a.status) {
      'COMPLETED' => ProviderApptKind.completed,
      'CANCELLED' => ProviderApptKind.cancelled,
      _ => ProviderApptKind.opened,
    };

    return ProviderAppointment(
      id: a.id,
      clientName: a.clientName ?? 'Client',
      timeRange: '${fmt(start)} - ${fmt(end)}',
      kind: kind,
      avatarUrl: a.clientAvatar,
      dto: a,
    );
  }
}

class LinkableSalon {
  const LinkableSalon({
    required this.id,
    required this.name,
    required this.address,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String address;
  final String imageUrl;

  factory LinkableSalon.fromShop(ShopDto shop) {
    return LinkableSalon(
      id: shop.id,
      name: shop.name,
      address: shop.addressLine,
      imageUrl: shop.imageUrl,
    );
  }
}
