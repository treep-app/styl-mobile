import '../../../core/network/api_models.dart';

enum SalonTypeFilter { any, salon, mobile }

/// Honest marketplace filters — only fields we actually have.
class SalonFilters {
  const SalonFilters({
    this.distanceMiles = 5,
    this.maxPrice = 50,
    this.minRating,
    this.type = SalonTypeFilter.any,
    this.openNow = false,
    this.instantBooking = true,
    this.verifiedOnly = false,
  });

  static const defaults = SalonFilters();

  final double distanceMiles;
  final double maxPrice;
  final double? minRating;
  final SalonTypeFilter type;
  final bool openNow;
  final bool instantBooking;
  final bool verifiedOnly;

  bool get isUnboundedPrice => maxPrice >= 50;

  String get distanceLabel {
    final n = distanceMiles.round();
    return n == 1 ? '1 mile' : '$n miles';
  }

  String get priceLabel =>
      isUnboundedPrice ? '£0 – £50+' : '£0 – £${maxPrice.round()}';

  SalonFilters copyWith({
    double? distanceMiles,
    double? maxPrice,
    double? minRating,
    bool clearMinRating = false,
    SalonTypeFilter? type,
    bool? openNow,
    bool? instantBooking,
    bool? verifiedOnly,
  }) {
    return SalonFilters(
      distanceMiles: distanceMiles ?? this.distanceMiles,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      type: type ?? this.type,
      openNow: openNow ?? this.openNow,
      instantBooking: instantBooking ?? this.instantBooking,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
    );
  }

  List<AvailabilityShopDto> apply(List<AvailabilityShopDto> rows) {
    return rows.where(matches).toList();
  }

  bool matches(AvailabilityShopDto row) {
    if (row.shop.distanceKm != null && row.miles > distanceMiles + 0.05) {
      return false;
    }
    if (!isUnboundedPrice && row.minPrice > maxPrice) return false;
    final floor = minRating;
    if (floor != null) {
      if (row.shop.ratingCount <= 0 || row.shop.ratingAvg < floor) return false;
    }
    switch (type) {
      case SalonTypeFilter.any:
        break;
      case SalonTypeFilter.salon:
        if (!row.hasSalon) return false;
      case SalonTypeFilter.mobile:
        if (!row.hasMobile) return false;
    }
    if (openNow && !row.isOpenNow) return false;
    if (instantBooking && !row.instantBook) return false;
    if (verifiedOnly && !row.isVerified) return false;
    return true;
  }
}
