import 'styl_taxonomy.dart';

/// Shared salon + marketplace service templates (STYL master taxonomy).
abstract final class SalonServiceCatalog {
  static List<String> get categories =>
      StylTaxonomy.providerCategories.isNotEmpty
          ? StylTaxonomy.providerCategories
          : _fallbackCategories;

  static const _fallbackCategories = [
    'Barber',
    "Women's Hair",
    'Nails',
    'Lashes',
    'Braids',
    'Beard',
    'Colour',
    'Extensions',
    'Beauty',
  ];

  static List<SalonServiceTemplate> get templates {
    if (StylTaxonomy.templates.isEmpty) return _fallbackTemplates;
    return StylTaxonomy.templates
        .map(
          (t) => SalonServiceTemplate(
            category: t.category,
            name: t.name,
            description: t.description,
            defaultPrice: t.defaultPrice,
            defaultDurationMin: t.defaultDurationMin,
            subcategory: t.subcategory,
            tag: t.tag,
          ),
        )
        .toList();
  }

  static List<SalonServiceTemplate> forCategory(String category) {
    final normalized = normalizeCategory(category);
    return templates.where((t) => t.category == normalized).toList();
  }

  static SalonServiceTemplate? byName(String name) {
    final template = StylTaxonomy.findTemplate(name);
    if (template != null) {
      return SalonServiceTemplate(
        category: template.category,
        name: template.name,
        description: template.description,
        defaultPrice: template.defaultPrice,
        defaultDurationMin: template.defaultDurationMin,
        subcategory: template.subcategory,
        tag: template.tag,
      );
    }
    for (final t in templates) {
      if (t.name.toLowerCase() == name.toLowerCase()) return t;
    }
    return null;
  }

  static String categoryForName(String name) {
    final fromTemplate = byName(name);
    if (fromTemplate != null) return fromTemplate.category;
    final id = StylTaxonomy.discoveryCategoryId(name);
    final def = StylTaxonomy.discoveryById(id);
    if (def != null) return def.label;
    return 'Barber';
  }

  static String normalizeCategory(String? raw) =>
      StylTaxonomy.normalizeProviderCategory(raw);

  static Map<String, List<String>> get searchSections {
    final map = <String, List<String>>{};
    for (final c in categories) {
      map[c] = forCategory(c).map((t) => t.name).toList();
    }
    return map;
  }

  static const _fallbackTemplates = <SalonServiceTemplate>[];
}

class SalonServiceTemplate {
  const SalonServiceTemplate({
    required this.category,
    required this.name,
    required this.description,
    required this.defaultPrice,
    required this.defaultDurationMin,
    this.subcategory = '',
    this.tag = 'All',
  });

  final String category;
  final String name;
  final String description;
  final double defaultPrice;
  final int defaultDurationMin;
  final String subcategory;
  final String tag;
}
