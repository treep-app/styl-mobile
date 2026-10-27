import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../data/catalog_api.dart';
import '../data/looks_catalog.dart';
import 'browse_services_screen.dart';
import 'looks_ui.dart';
import 'look_details_screen.dart';

class MarketplaceSearchArgs {
  const MarketplaceSearchArgs({this.initialQuery, this.area});

  final String? initialQuery;
  final String? area;
}

enum _SearchTab { all, salons, professionals, services, looks }

/// Home search — browse categories/looks, then search salons by name.
class MarketplaceSearchScreen extends StatefulWidget {
  const MarketplaceSearchScreen({super.key, this.args = const MarketplaceSearchArgs()});

  final MarketplaceSearchArgs args;

  @override
  State<MarketplaceSearchScreen> createState() => _MarketplaceSearchScreenState();
}

class _MarketplaceSearchScreenState extends State<MarketplaceSearchScreen> {
  late final TextEditingController _search;
  var _tab = _SearchTab.all;
  var _query = '';
  var _loading = false;
  CatalogSearchResult? _result;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.args.initialQuery ?? '');
    _query = _search.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthController>().loadMarketplace(
        area: widget.args.area,
      );
      if (_query.isNotEmpty) await _runSearch(_query);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final q = value.trim();
    setState(() => _query = q);
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() => _result = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 220), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() => _loading = true);
    try {
      final result = await context.read<AuthController>().searchMarketplace(
        q: q,
        area: widget.args.area,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openShop(ShopDto shop) {
    Navigator.of(context).pushNamed(
      AppRoutes.providerDetail,
      arguments: ProviderDetailArgs(
        shopId: shop.id,
        name: shop.name,
        subtitle: shop.areaLabel,
        rating: shop.ratingAvg,
        distance: shop.distanceLabel,
        address: shop.addressLine,
        imageUrl: shop.imageUrl,
        description: shop.description,
      ),
    );
  }

  void _openPro(BarberDto pro) {
    final shopRef = pro.shops.isNotEmpty ? pro.shops.first : null;
    ShopDto? live;
    if (shopRef != null) {
      for (final s in context.read<AuthController>().marketplaceShops) {
        if (s.id == shopRef.id) {
          live = s;
          break;
        }
      }
    }
    Navigator.of(context).pushNamed(
      AppRoutes.providerDetail,
      arguments: ProviderDetailArgs(
        shopId: shopRef?.id ?? '',
        name: shopRef?.name ?? pro.displayName,
        subtitle: pro.subtitle,
        rating: pro.ratingAvg,
        distance: live?.distanceLabel ?? 'Nearby',
        address: shopRef?.addressLine ?? '',
        imageUrl: pro.avatarUrl ??
            (shopRef != null && shopRef.imageUrls.isNotEmpty
                ? shopRef.imageUrls.first
                : null),
        description: live?.description,
        barberUserId: pro.id,
      ),
    );
  }

  void _openLook(StyleLook look) {
    Navigator.of(context).pushNamed(
      AppRoutes.lookDetails,
      arguments: LookDetailsArgs(lookId: look.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final browsing = _query.isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onQueryChanged,
                      onSubmitted: (v) => _runSearch(v.trim()),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: LooksUi.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search salons, looks, services',
                        hintStyle: const TextStyle(
                          color: LooksUi.muted,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: LooksUi.muted),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  _onQueryChanged('');
                                },
                                icon: const Icon(Icons.close_rounded, color: LooksUi.muted),
                              ),
                        filled: true,
                        fillColor: LooksUi.searchFill,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: LooksUi.purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!browsing)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  children: [
                    for (final tab in _SearchTab.values) ...[
                      _FilterChip(
                        label: switch (tab) {
                          _SearchTab.all => 'All',
                          _SearchTab.salons => 'Salons',
                          _SearchTab.professionals => 'Professionals',
                          _SearchTab.services => 'Services',
                          _SearchTab.looks => 'Looks',
                        },
                        selected: _tab == tab,
                        onTap: () => setState(() => _tab = tab),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: browsing
                  ? _BrowseBody(
                      categories: auth.marketplaceCategories,
                      looks: auth.marketplaceLooks,
                      onCategory: (c) {
                        Navigator.of(context).pushNamed(
                          AppRoutes.browseServices,
                          arguments: BrowseServicesArgs(categoryId: c.id),
                        );
                      },
                      onLook: _openLook,
                    )
                  : _loading && _result == null
                      ? const Center(child: CircularProgressIndicator())
                      : _ResultsBody(
                          tab: _tab,
                          result: _result,
                          onShop: _openShop,
                          onPro: _openPro,
                          onLook: _openLook,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseBody extends StatelessWidget {
  const _BrowseBody({
    required this.categories,
    required this.looks,
    required this.onCategory,
    required this.onLook,
  });

  final List<LookCategory> categories;
  final List<StyleLook> looks;
  final ValueChanged<LookCategory> onCategory;
  final ValueChanged<StyleLook> onLook;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'Browse categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in categories)
              ActionChip(
                label: Text(LooksCatalog.browseTitle(c.id)),
                onPressed: () => onCategory(c),
                backgroundColor: LooksUi.purpleSoft,
                side: BorderSide.none,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: LooksUi.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Popular looks',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (looks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Looks appear here from salon services.',
              style: TextStyle(color: LooksUi.muted),
            ),
          )
        else
          for (final look in looks.take(12))
            _ServiceLookRow(look: look, onTap: () => onLook(look)),
      ],
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.tab,
    required this.result,
    required this.onShop,
    required this.onPro,
    required this.onLook,
  });

  final _SearchTab tab;
  final CatalogSearchResult? result;
  final ValueChanged<ShopDto> onShop;
  final ValueChanged<BarberDto> onPro;
  final ValueChanged<StyleLook> onLook;

  @override
  Widget build(BuildContext context) {
    final shops = result?.shops ?? const <ShopDto>[];
    final pros = result?.professionals ?? const <BarberDto>[];
    final looks = result?.looks ?? const <StyleLook>[];
    final top = result?.topShop;
    final others = top == null ? shops : shops.where((s) => s.id != top.id).toList();
    final showSalons = tab == _SearchTab.all || tab == _SearchTab.salons;
    final showPros = tab == _SearchTab.all || tab == _SearchTab.professionals;
    final showLooks =
        tab == _SearchTab.all || tab == _SearchTab.services || tab == _SearchTab.looks;

    if (shops.isEmpty && pros.isEmpty && looks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No matches nearby. Try another name or area.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LooksUi.muted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      children: [
        if (showSalons && top != null) ...[
          const _SectionLabel('Top result'),
          _SalonRow(shop: top, onTap: () => onShop(top)),
        ],
        if (showSalons && others.isNotEmpty) ...[
          const _SectionLabel('Other salons'),
          for (final shop in others) _SalonRow(shop: shop, onTap: () => onShop(shop)),
        ],
        if (showPros && pros.isNotEmpty) ...[
          const _SectionLabel('Professionals'),
          for (final pro in pros) _ProRow(pro: pro, onTap: () => onPro(pro)),
        ],
        if (showLooks && looks.isNotEmpty) ...[
          _SectionLabel(tab == _SearchTab.looks ? 'Looks' : 'Services'),
          for (final look in looks) _ServiceLookRow(look: look, onTap: () => onLook(look)),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: LooksUi.ink,
        ),
      ),
    );
  }
}

class _SalonRow extends StatelessWidget {
  const _SalonRow({required this.shop, required this.onTap});

  final ShopDto shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 56,
          height: 56,
          child: LookPhoto(url: shop.hasPhoto ? shop.imageUrl : null),
        ),
      ),
      title: VerifiedSalonName(
        name: shop.name,
        isVerified: shop.isVerified,
        badgeSize: 16,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: LooksUi.ink,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shop.isVerified ? 'Verified salon' : 'Salon',
            style: const TextStyle(color: LooksUi.muted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B400)),
              const SizedBox(width: 2),
              Text(
                shop.ratingLabel,
                style: const TextStyle(fontSize: 13, color: LooksUi.ink),
              ),
            ],
          ),
          Text(
            '${shop.distanceLabel} · ${shop.areaLabel}',
            style: const TextStyle(fontSize: 13, color: LooksUi.muted),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded, color: LooksUi.muted),
    );
  }
}

class _ProRow extends StatelessWidget {
  const _ProRow({required this.pro, required this.onTap});

  final BarberDto pro;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: StylAvatar(
        size: 56,
        imageUrl: pro.avatarUrl,
        name: pro.displayName,
      ),
      title: Text(
        pro.displayName,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: LooksUi.ink,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pro.subtitle, style: const TextStyle(color: LooksUi.muted, fontSize: 13)),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B400)),
              const SizedBox(width: 2),
              Text(
                pro.ratingLabel,
                style: const TextStyle(fontSize: 13, color: LooksUi.ink),
              ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right_rounded, color: LooksUi.muted),
    );
  }
}

class _ServiceLookRow extends StatelessWidget {
  const _ServiceLookRow({required this.look, required this.onTap});

  final StyleLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      leading: ClipOval(
        child: SizedBox(
          width: 56,
          height: 56,
          child: LookPhoto(url: look.imageUrl),
        ),
      ),
      title: Text(
        look.name,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: LooksUi.ink,
        ),
      ),
      subtitle: const Text(
        'Find salons and professionals',
        style: TextStyle(color: LooksUi.muted, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: LooksUi.muted),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? LooksUi.purple : LooksUi.chipIdle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : LooksUi.muted,
          ),
        ),
      ),
    );
  }
}
