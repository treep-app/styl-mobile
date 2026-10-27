import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../data/looks_catalog.dart';
import 'look_details_screen.dart';
import 'looks_ui.dart';
import 'save_heart_button.dart';

/// Looksy Saved — Salons, Professionals, Looks from hearts the user actually taps.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => SavedScreenState();
}

class SavedScreenState extends State<SavedScreen> {
  var _tab = 0;
  var _loading = true;
  List<ShopDto> _shops = const [];
  List<BarberDto> _pros = const [];
  List<StyleLook> _looks = const [];

  Future<void> reload() => _load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    final store = SessionStore();
    final lookIds = await store.readSavedLookIds();
    final shopIds = await store.readSavedShopIds();
    final barberIds = await store.readSavedBarberIds();
    await auth.loadMarketplace();
    if (!mounted) return;
    setState(() {
      _shops = auth.marketplaceShops
          .where((s) => shopIds.contains(s.id))
          .toList();
      _pros = auth.marketplaceProfessionals
          .where((p) => barberIds.contains(p.id))
          .toList();
      _looks = auth.marketplaceLooks
          .where((l) => lookIds.contains(l.id))
          .toList();
      _loading = false;
    });
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
        imageUrl: shop.hasPhoto ? shop.imageUrl : null,
        description: shop.description,
        barberUserId: shop.ownerUserId,
      ),
    );
  }

  void _openPro(BarberDto pro) {
    final home = pro.shops.isNotEmpty ? pro.shops.first : null;
    if (home == null) return;
    Navigator.of(context).pushNamed(
      AppRoutes.providerDetail,
      arguments: ProviderDetailArgs(
        shopId: home.id,
        name: home.name,
        subtitle: pro.displayName,
        rating: pro.ratingAvg,
        distance: pro.distanceKm == null
            ? 'Nearby'
            : '${(pro.distanceKm! * 0.621371).toStringAsFixed(1)} miles',
        address: home.addressLine ?? '',
        imageUrl: home.imageUrls.isNotEmpty ? home.imageUrls.first : pro.avatarUrl,
        barberUserId: pro.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Saved',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: LooksUi.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _SavedTab(
                    label: 'Salons',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 8),
                  _SavedTab(
                    label: 'Professionals',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 8),
                  _SavedTab(
                    label: 'Looks',
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: LooksUi.purple,
                      onRefresh: _load,
                      child: _tab == 0
                          ? _SalonList(
                              shops: _shops,
                              onOpen: _openShop,
                              onChanged: _load,
                            )
                          : _tab == 1
                              ? _ProList(
                                  pros: _pros,
                                  onOpen: _openPro,
                                  onChanged: _load,
                                )
                              : _LookList(
                                  looks: _looks,
                                  onChanged: _load,
                                ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTab extends StatelessWidget {
  const _SavedTab({
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? LooksUi.purple : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? LooksUi.purple : const Color(0xFFE4E0F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : LooksUi.ink,
          ),
        ),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 24),
      children: [
        const Icon(Icons.favorite_border, size: 40, color: LooksUi.muted),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: LooksUi.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _SalonList extends StatelessWidget {
  const _SalonList({
    required this.shops,
    required this.onOpen,
    required this.onChanged,
  });

  final List<ShopDto> shops;
  final ValueChanged<ShopDto> onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return const _EmptySaved(
        message: 'Heart a salon on Home, Map, or a profile to save it here.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
      itemCount: shops.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F0F8)),
      itemBuilder: (context, i) {
        final shop = shops[i];
        return InkWell(
          onTap: () => onOpen(shop),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: LookPhoto(
                      url: shop.hasPhoto ? shop.imageUrl : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: LooksUi.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF5B400),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            shop.ratingCount > 0
                                ? '${shop.ratingAvg.toStringAsFixed(1)} (${shop.ratingCount})'
                                : 'New',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: LooksUi.ink,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${shop.distanceLabel} · ${shop.areaLabel}',
                        style: const TextStyle(
                          color: LooksUi.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SaveShopHeart(
                  shopId: shop.id,
                  barberUserId: shop.ownerUserId,
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProList extends StatelessWidget {
  const _ProList({
    required this.pros,
    required this.onOpen,
    required this.onChanged,
  });

  final List<BarberDto> pros;
  final ValueChanged<BarberDto> onOpen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (pros.isEmpty) {
      return const _EmptySaved(
        message: 'Heart a professional when you save their salon to see them here.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
      itemCount: pros.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F0F8)),
      itemBuilder: (context, i) {
        final pro = pros[i];
        final shop = pro.shops.isNotEmpty ? pro.shops.first.name : null;
        return InkWell(
          onTap: () => onOpen(pro),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                StylAvatar(
                  size: 72,
                  imageUrl: pro.avatarUrl,
                  name: pro.displayName,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pro.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: LooksUi.ink,
                        ),
                      ),
                      Text(
                        [
                          pro.specialty?.trim(),
                          shop,
                        ].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: const TextStyle(color: LooksUi.muted, fontSize: 13),
                      ),
                      if (pro.ratingCount > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF5B400),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              pro.ratingLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: LooksUi.ink,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                SaveBarberHeart(
                  barberUserId: pro.id,
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LookList extends StatelessWidget {
  const _LookList({required this.looks, required this.onChanged});

  final List<StyleLook> looks;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    if (looks.isEmpty) {
      return const _EmptySaved(
        message: 'Heart a look to save it here.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
      itemCount: looks.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF3F0F8)),
      itemBuilder: (context, i) {
        final look = looks[i];
        return InkWell(
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.lookDetails,
              arguments: LookDetailsArgs(lookId: look.id),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LookPhoto(
                    url: look.imageUrl,
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        look.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: LooksUi.ink,
                        ),
                      ),
                      Text(
                        'From ${look.priceLabel}',
                        style: const TextStyle(
                          color: LooksUi.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                SaveLookHeart(
                  lookId: look.id,
                  onChanged: (_) => onChanged(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
