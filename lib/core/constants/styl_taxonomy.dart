import 'dart:convert';

import 'package:flutter/services.dart';

/// STYL master taxonomy (shared with backend `taxonomy/styl_service_taxonomy.json`).
abstract final class StylTaxonomy {
  static const assetPath = '../taxonomy/styl_service_taxonomy.json';

  static bool _loaded = false;
  static String version = '1.0.0';
  static List<DiscoveryCategoryDef> discoveryCategories = const [];
  static List<String> providerCategories = const [];
  static List<StylServiceTemplateDef> templates = const [];

  static final Map<String, String> _categoryAliases = {};
  static final Map<String, String> _labelToId = {};
  static final Map<String, StylServiceTemplateDef> _templateByName = {};

  static Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    version = json['version'] as String? ?? '1.0.0';

    discoveryCategories = (json['discoveryCategories'] as List<dynamic>? ?? [])
        .map((e) => DiscoveryCategoryDef.fromJson(e as Map<String, dynamic>))
        .toList();

    providerCategories = (json['providerCategories'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    templates = (json['templates'] as List<dynamic>? ?? [])
        .map((e) => StylServiceTemplateDef.fromJson(e as Map<String, dynamic>))
        .toList();

    _categoryAliases.clear();
    final aliases = json['categoryAliases'] as Map<String, dynamic>? ?? {};
    for (final entry in aliases.entries) {
      _categoryAliases[entry.key.toLowerCase()] = entry.value.toString();
    }

    _labelToId.clear();
    for (final c in discoveryCategories) {
      _labelToId[c.label] = c.id;
    }

    _templateByName.clear();
    for (final t in templates) {
      _registerTemplateName(t.name, t);
      for (final alias in t.aliases) {
        _registerTemplateName(alias, t);
      }
    }

    _loaded = true;
  }

  static void _registerTemplateName(String name, StylServiceTemplateDef template) {
    _templateByName[_normalizeName(name)] = template;
  }

  static String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String normalizeProviderCategory(String? raw) {
    final c = (raw ?? '').trim();
    if (c.isEmpty) return 'Barber';
    final key = c.toLowerCase();
    final aliased = _categoryAliases[key];
    if (aliased != null) return aliased;
    if (providerCategories.contains(c)) return c;
    return 'Barber';
  }

  static String providerCategoryId(String label) {
    final normalized = normalizeProviderCategory(label);
    return _labelToId[normalized] ?? 'more';
  }

  static StylServiceTemplateDef? findTemplate(String serviceName) {
    return _templateByName[_normalizeName(serviceName)];
  }

  static String discoveryCategoryId(String serviceName, {String? providerCategory}) {
    final template = findTemplate(serviceName);
    if (template != null) {
      return providerCategoryId(template.category);
    }
    if (providerCategory != null && providerCategory.trim().isNotEmpty) {
      final id = providerCategoryId(normalizeProviderCategory(providerCategory));
      if (id != 'more') return id;
    }
    final n = _normalizeName(serviceName);
    for (final c in discoveryCategories) {
      if (c.keywords.any((k) => n.contains(k.toLowerCase()))) {
        return c.id;
      }
    }
    return 'more';
  }

  static String browseTitleFor(String categoryId) {
    for (final c in discoveryCategories) {
      if (c.id == categoryId) return c.browseTitle;
    }
    if (categoryId == 'more') return 'More';
    return categoryId;
  }

  static List<String> browseTagsFor(String categoryId) {
    for (final c in discoveryCategories) {
      if (c.id == categoryId) return c.browseTags;
    }
    return const ['All'];
  }

  static DiscoveryCategoryDef? discoveryById(String id) {
    for (final c in discoveryCategories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class DiscoveryCategoryDef {
  const DiscoveryCategoryDef({
    required this.id,
    required this.label,
    required this.browseTitle,
    required this.keywords,
    required this.browseTags,
  });

  final String id;
  final String label;
  final String browseTitle;
  final List<String> keywords;
  final List<String> browseTags;

  factory DiscoveryCategoryDef.fromJson(Map<String, dynamic> json) {
    return DiscoveryCategoryDef(
      id: json['id'] as String,
      label: json['label'] as String,
      browseTitle: json['browseTitle'] as String? ?? json['label'] as String,
      keywords: (json['keywords'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      browseTags: (json['browseTags'] as List<dynamic>? ?? ['All'])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class StylServiceTemplateDef {
  const StylServiceTemplateDef({
    required this.category,
    required this.subcategory,
    required this.tag,
    required this.name,
    required this.description,
    required this.defaultPrice,
    required this.defaultDurationMin,
    this.aliases = const [],
  });

  final String category;
  final String subcategory;
  final String tag;
  final String name;
  final List<String> aliases;
  final String description;
  final double defaultPrice;
  final int defaultDurationMin;

  factory StylServiceTemplateDef.fromJson(Map<String, dynamic> json) {
    return StylServiceTemplateDef(
      category: json['category'] as String,
      subcategory: json['subcategory'] as String? ?? '',
      tag: json['tag'] as String? ?? 'All',
      name: json['name'] as String,
      aliases: (json['aliases'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      description: json['description'] as String? ?? '',
      defaultPrice: (json['defaultPrice'] as num?)?.toDouble() ?? 0,
      defaultDurationMin: json['defaultDurationMin'] as int? ?? 30,
    );
  }
}
