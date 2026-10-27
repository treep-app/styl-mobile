import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../data/looks_catalog.dart';
import 'available_today_screen.dart';
import 'looks_ui.dart';
import 'save_heart_button.dart';

class FindProfessionalsArgs {
  const FindProfessionalsArgs({required this.lookId});

  final String lookId;
}

enum _Sort { match, distance, price, rating }

class FindProfessionalsScreen extends StatefulWidget {
  const FindProfessionalsScreen({super.key, required this.args});

  final FindProfessionalsArgs args;

  @override
  State<FindProfessionalsScreen> createState() => _FindProfessionalsScreenState();
}

class _FindProfessionalsScreenState extends State<FindProfessionalsScreen> {
  var _sort = _Sort.match;
  var _loading = true;
  String? _error;
  List<_ProCard> _pros = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AuthController>().loadMarketplace();
      if (mounted) await _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    try {
      await auth.loadMarketplace();
      final look = auth.lookById(widget.args.lookId);
      if (look == null) {
        if (!mounted) return;
        setState(() {
          _error = 'This look is no longer available.';
          _loading = false;
          _pros = const [];
        });
        return;
      }
      var shops = auth.shopsForLook(look);
      if (shops.isEmpty) {
        final needle = look.name.toLowerCase();
        shops = auth.marketplaceShops.where((s) {
          return s.services.any((svc) => svc.name.toLowerCase().contains(needle));
        }).toList();
      }
      final cards = <_ProCard>[];
      for (final shop in shops) {
        final matching = shop.services.where(
          (s) => s.name.toLowerCase() == look.name.toLowerCase(),
        );
        final price = matching.isNotEmpty
            ? matching.map((s) => s.priceAmount).reduce((a, b) => a < b ? a : b)
            : look.priceFrom;
        final exact = matching.isNotEmpty;
        cards.add(
          _ProCard(
            shop: shop,
            title: shop.name,
            subtitle: shop.area ?? shop.addressLine,
            rating: shop.ratingAvg,
            reviewCount: shop.ratingCount,
            distance: shop.distanceLabel,
            priceFrom: price.round(),
            match: exact ? 100 : 80,
            imageUrl: shop.hasPhoto ? shop.imageUrl : null,
            avatarUrl: shop.hasPhoto ? shop.imageUrl : null,
            barberUserId: shop.ownerUserId,
            thumbs: shop.imageUrls,
          ),
        );
      }
      cards.sort((a, b) => b.match.compareTo(a.match));
      if (!mounted) return;
      setState(() {
        _pros = cards;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  List<_ProCard> get _sorted {
    final list = [..._pros];
    switch (_sort) {
      case _Sort.match:
        list.sort((a, b) => b.match.compareTo(a.match));
      case _Sort.distance:
        list.sort((a, b) => a.distance.compareTo(b.distance));
      case _Sort.price:
        list.sort((a, b) => a.priceFrom.compareTo(b.priceFrom));
      case _Sort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final look = context.watch<AuthController>().lookById(widget.args.lookId);
    final tabs = [
      ('Best match', _Sort.match),
      ('Distance', _Sort.distance),
      ('Price', _Sort.price),
      ('Rating', _Sort.rating),
    ];

    if (look == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : Text(_error ?? 'This look is no longer available.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        title: Text(
          '${_pros.length} professionals\nnear you can do this style',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.2,
            color: LooksUi.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Available times',
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.availableToday,
                arguments: AvailableTodayArgs(
                  lookId: look.id,
                  lookName: look.name,
                ),
              );
            },
            icon: const Icon(Icons.event_available_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = _sort == tabs[i].$2;
                return ChoiceChip(
                  label: Text(tabs[i].$1),
                  selected: selected,
                  onSelected: (_) => setState(() => _sort = tabs[i].$2),
                  selectedColor: AppColors.brandPrimary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: const Color(0xFFF3F7FB),
                  side: BorderSide.none,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Material(
              color: LooksUi.purpleSoft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.availableToday,
                    arguments: AvailableTodayArgs(
                      lookId: look.id,
                      lookName: look.name,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, color: LooksUi.purple),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'See who has times today',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: LooksUi.ink,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: LooksUi.purple),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _sorted.isEmpty
                        ? const Center(child: Text('No professionals nearby yet.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _sorted.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, i) {
                              final p = _sorted[i];
                              return _ProTile(
                                pro: p,
                                look: look,
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.providerDetail,
                                    arguments: ProviderDetailArgs(
                                      shopId: p.shop.id,
                                      name: p.title,
                                      subtitle: look.name,
                                      rating: p.rating,
                                      distance: p.distance,
                                      address: p.shop.addressLine,
                                      imageUrl: p.imageUrl,
                                      description: p.shop.description,
                                      barberUserId: p.barberUserId,
                                      lookName: look.name,
                                      lookImageUrl: look.imageUrl,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ProCard {
  const _ProCard({
    required this.shop,
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.reviewCount,
    required this.distance,
    required this.priceFrom,
    required this.match,
    this.imageUrl,
    this.avatarUrl,
    this.barberUserId,
    this.thumbs = const [],
  });

  final ShopDto shop;
  final String title;
  final String subtitle;
  final double rating;
  final int reviewCount;
  final String distance;
  final int priceFrom;
  final int match;
  final String? imageUrl;
  final String? avatarUrl;
  final String? barberUserId;
  final List<String> thumbs;
}

class _ProTile extends StatelessWidget {
  const _ProTile({required this.pro, required this.look, required this.onTap});

  final _ProCard pro;
  final StyleLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StylAvatar(size: 56, imageUrl: pro.avatarUrl, name: pro.title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pro.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        SaveShopHeart(
                          shopId: pro.shop.id,
                          barberUserId: pro.barberUserId,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (pro.reviewCount > 0)
                          '★ ${pro.rating.toStringAsFixed(1)} (${pro.reviewCount})'
                        else
                          'New',
                        pro.subtitle,
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${pro.distance} · From £${pro.priceFrom}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8EE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pro.match == 100 ? 'Offers this' : 'Similar services',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (pro.thumbs.isNotEmpty || look.hasImage) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: pro.thumbs.isNotEmpty
                              ? pro.thumbs.length.clamp(0, 4)
                              : 1,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LookPhoto(
                                url: pro.thumbs.isNotEmpty
                                    ? pro.thumbs[i]
                                    : look.imageUrl,
                                width: 52,
                                height: 52,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
