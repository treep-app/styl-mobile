import 'package:flutter/material.dart';

import '../../../core/constants/styl_taxonomy.dart';
import '../../../core/utils/media_url.dart';

/// Category chrome (icons / colours). Look *content* comes from the API.
class LookCategory {
  const LookCategory({
    required this.id,
    required this.label,
    required this.icon,
    this.serviceKeywords = const [],
    this.orbColor = const Color(0xFFF3EDE4),
    this.illustrationUrl,
    this.lookCount = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> serviceKeywords;
  final Color orbColor;
  final String? illustrationUrl;
  final int lookCount;

  LookCategory copyWith({
    String? illustrationUrl,
    int? lookCount,
  }) {
    return LookCategory(
      id: id,
      label: label,
      icon: icon,
      serviceKeywords: serviceKeywords,
      orbColor: orbColor,
      illustrationUrl: illustrationUrl ?? this.illustrationUrl,
      lookCount: lookCount ?? this.lookCount,
    );
  }

  factory LookCategory.fromApi(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? 'more';
    final base = LooksCatalog.taxonomyById(id);
    return base.copyWith(
      illustrationUrl: json['illustrationUrl'] as String?,
      lookCount: json['lookCount'] as int? ?? 0,
    );
  }
}

class StyleLook {
  const StyleLook({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    this.tag = 'All',
    this.imageUrl,
    this.priceFrom = 0,
    this.prosNearby = 0,
    this.currency = 'GBP',
    this.durationMin = 30,
    this.shopIds = const [],
    this.serviceIds = const [],
  });

  final String id;
  final String categoryId;
  final String name;
  final String tag;
  final String? imageUrl;
  final String description;
  final double priceFrom;
  final int prosNearby;
  final String currency;
  final int durationMin;
  final List<String> shopIds;
  final List<String> serviceIds;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  String get priceLabel {
    final symbol = currency == 'GBP'
        ? '£'
        : currency == 'USD'
            ? '\$'
            : '$currency ';
    return '$symbol${priceFrom.toStringAsFixed(priceFrom % 1 == 0 ? 0 : 2)}';
  }

  factory StyleLook.fromJson(Map<String, dynamic> json) {
    return StyleLook(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String? ?? 'more',
      name: json['name'] as String? ?? 'Look',
      tag: json['tag'] as String? ?? 'All',
      imageUrl: resolveMediaUrl(json['imageUrl'] as String?),
      description: json['description'] as String? ?? '',
      priceFrom: (json['priceFrom'] as num?)?.toDouble() ?? 0,
      prosNearby: json['prosNearby'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      durationMin: json['durationMin'] as int? ?? 30,
      shopIds:
          (json['shopIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              const [],
      serviceIds:
          (json['serviceIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Visual taxonomy only — no dummy looks.
abstract final class LooksCatalog {
  static List<LookCategory> get taxonomy {
    if (StylTaxonomy.discoveryCategories.isNotEmpty) {
      return [
        for (final c in StylTaxonomy.discoveryCategories)
          LookCategory(
            id: c.id,
            label: c.label,
            icon: _iconForCategory(c.id),
            serviceKeywords: c.keywords,
            orbColor: _orbForCategory(c.id),
          ),
        moreCategory,
      ];
    }
    return _legacyTaxonomy;
  }

  static IconData _iconForCategory(String id) {
    return _legacyTaxonomy
        .firstWhere(
          (c) => c.id == id,
          orElse: () => moreCategory,
        )
        .icon;
  }

  static Color _orbForCategory(String id) {
    return _legacyTaxonomy
        .firstWhere(
          (c) => c.id == id,
          orElse: () => moreCategory,
        )
        .orbColor;
  }

  static const _legacyTaxonomy = <LookCategory>[
    LookCategory(
      id: 'barber',
      label: 'Barber',
      icon: Icons.content_cut_rounded,
      serviceKeywords: [
        'cut',
        'fade',
        'taper',
        'beard',
        'hair',
        'shape',
        'kids',
      ],
    ),
    LookCategory(
      id: 'womens',
      label: "Women's Hair",
      icon: Icons.face_3_outlined,
      serviceKeywords: ['cut', 'color', 'blow', 'hair', 'silk', 'bangs'],
    ),
    LookCategory(
      id: 'nails',
      label: 'Nails',
      icon: Icons.back_hand_outlined,
      serviceKeywords: [
        'nail',
        'manicure',
        'pedicure',
        'acrylic',
        'gel',
        'fill',
      ],
      orbColor: Color(0xFFE4F3EE),
    ),
    LookCategory(
      id: 'lashes',
      label: 'Lashes',
      icon: Icons.visibility_outlined,
      serviceKeywords: ['lash', 'brow', 'lift'],
    ),
    LookCategory(
      id: 'braids',
      label: 'Braids',
      icon: Icons.grain_rounded,
      serviceKeywords: ['braid', 'cornrow', 'twist', 'knotless'],
    ),
    LookCategory(
      id: 'beard',
      label: 'Beard',
      icon: Icons.face_retouching_natural,
      serviceKeywords: ['beard', 'trim', 'shave'],
    ),
    LookCategory(
      id: 'colour',
      label: 'Colour',
      icon: Icons.palette_outlined,
      serviceKeywords: ['color', 'colour', 'highlight', 'tint', 'balayage'],
    ),
    LookCategory(
      id: 'extensions',
      label: 'Extensions',
      icon: Icons.auto_awesome,
      serviceKeywords: ['extension', 'weave', 'tape', 'sew'],
    ),
    LookCategory(
      id: 'beauty',
      label: 'Beauty',
      icon: Icons.spa_outlined,
      serviceKeywords: ['facial', 'beauty', 'skin', 'wax', 'massage'],
      orbColor: Color(0xFFF8E4EE),
    ),
    LookCategory(
      id: 'more',
      label: 'More',
      icon: Icons.more_horiz_rounded,
    ),
  ];

  static const moreCategory = LookCategory(
    id: 'more',
    label: 'More',
    icon: Icons.more_horiz_rounded,
  );

  static LookCategory taxonomyById(String id) =>
      taxonomy.firstWhere((c) => c.id == id, orElse: () => moreCategory);

  static LookCategory byId(String id) => taxonomyById(id);

  static String browseTitle(String id) {
    if (StylTaxonomy.discoveryCategories.isNotEmpty) {
      return StylTaxonomy.browseTitleFor(id);
    }
    if (id == 'barber') return 'Barbering';
    return taxonomyById(id).label;
  }

  static List<String> browseTags(String categoryId) {
    if (StylTaxonomy.discoveryCategories.isNotEmpty) {
      return StylTaxonomy.browseTagsFor(categoryId);
    }
    if (categoryId == 'barber') {
      return const ['All', 'Fades', 'Tapers', 'Beard', 'Kids'];
    }
    return const ['All'];
  }
}

class LookPhoto extends StatelessWidget {
  const LookPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(url);
    if (resolved == null || resolved.trim().isEmpty) {
      return ColoredBox(
        color: const Color(0xFFF3EDE4),
        child: SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.content_cut_rounded, color: Color(0xFF1A1633)),
        ),
      );
    }
    return Image.network(
      resolved,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => ColoredBox(
        color: const Color(0xFFF3EDE4),
        child: SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.content_cut_rounded),
        ),
      ),
    );
  }
}
