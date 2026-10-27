import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_models.dart';
import '../../../core/notifications/notification_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../data/looks_catalog.dart';
import 'browse_services_screen.dart';
import 'choose_look_screen.dart';
import 'customer_shell_tabs.dart';
import 'find_professionals_screen.dart';
import 'find_this_look_screen.dart';
import 'location_search_screen.dart';
import 'look_details_screen.dart';
import 'looks_ui.dart';
import 'looksy_category_icon.dart';
import 'marketplace_search_screen.dart';
import 'nearby_map_screen.dart';

/// Customer home — marketplace dashboard matching the attached look-first UI.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _search = TextEditingController();
  final _store = SessionStore();
  String _location = 'Kingston upon Thames';
  List<ShopDto> _shops = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthController>();
    final saved = await _store.readLocationLabel();
    await auth.loadMarketplace(
      force: true,
      area: saved.isNotEmpty ? saved : null,
    );
    if (!mounted) return;
    final shops = auth.marketplaceShops;
    final location = saved.isNotEmpty
        ? saved
        : (shops.isNotEmpty && (shops.first.area ?? '').trim().isNotEmpty
            ? shops.first.area!.trim()
            : 'Kingston upon Thames');
    setState(() {
      _location = location;
      _shops = shops;
    });
  }

  void _openCategory(LookCategory category) {
    if (category.id == 'more') {
      _showMoreCategories();
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.browseServices,
      arguments: BrowseServicesArgs(categoryId: category.id),
    );
  }

  void _openSearch({String? query}) {
    Navigator.of(context).pushNamed(
      AppRoutes.marketplaceSearch,
      arguments: MarketplaceSearchArgs(
        initialQuery: query ?? _search.text.trim(),
        area: _location,
      ),
    );
  }

  Future<void> _pickLocation() async {
    final chosen = await Navigator.of(context).pushNamed(
      AppRoutes.locationSearch,
      arguments: LocationSearchArgs(currentLocation: _location),
    );
    if (chosen is! String || chosen.trim().isEmpty) return;
    await _store.setLocationLabel(chosen);
    if (!mounted) return;
    setState(() => _location = chosen);
    await context.read<AuthController>().loadMarketplace(force: true, area: chosen);
  }

  Future<void> _pickLookPhoto({bool camera = false}) async {
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
    );
    if (file == null || !mounted) return;
    Navigator.of(context).pushNamed(
      AppRoutes.findThisLook,
      arguments: FindThisLookArgs(photoPath: file.path),
    );
  }

  void _openLook(StyleLook look) {
    Navigator.of(context).pushNamed(
      AppRoutes.lookDetails,
      arguments: LookDetailsArgs(lookId: look.id),
    );
  }

  void _openShop(ShopDto shop) {
    Navigator.of(context).pushNamed(
      AppRoutes.providerDetail,
      arguments: ProviderDetailArgs(
        shopId: shop.id,
        name: shop.name,
        subtitle: shop.area ?? 'Professional',
        rating: shop.ratingAvg,
        distance: shop.distanceLabel,
        address: shop.addressLine,
        imageUrl: shop.imageUrl,
        description: shop.description,
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    await _store.setLocationLabel('Current location');
    if (!mounted) return;
    setState(() => _location = 'Current location');
    await context.read<AuthController>().loadMarketplace(
      force: true,
      area: 'Current location',
    );
  }

  void _showMoreCategories() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All services',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: LooksCatalog.taxonomy.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 82,
                  ),
                  itemBuilder: (context, i) {
                    final c = LooksCatalog.taxonomy[i];
                    return _CategoryTile(
                      category: c,
                      onTap: () {
                        Navigator.pop(context);
                        _openCategory(c);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final popular = auth.marketplaceLooks.take(8).toList();
    final homeCats = auth.marketplaceCategories.isNotEmpty
        ? auth.marketplaceCategories.take(10).toList()
        : LooksCatalog.taxonomy;
    final topShops = [...(auth.marketplaceShops.isNotEmpty ? auth.marketplaceShops : _shops)]
      ..sort((a, b) {
        final byRating = b.ratingAvg.compareTo(a.ratingAvg);
        if (byRating != 0) return byRating;
        return b.ratingCount.compareTo(a.ratingCount);
      });
    final featured = topShops.where((s) => s.ratingCount > 0).take(8).toList();
    const heroUrl = LooksUi.heroImage;
    final firstLookId = popular.isNotEmpty ? popular.first.id : null;
    final firstCategoryId =
        homeCats.isNotEmpty ? homeCats.first.id : 'barber';

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        color: LooksUi.purple,
        onRefresh: _bootstrap,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 16, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'STYL',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: LooksUi.ink,
                            letterSpacing: -0.8,
                            height: 1,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final inbox =
                              context.read<NotificationController>();
                          await Navigator.of(context)
                              .pushNamed(AppRoutes.notifications);
                          if (!mounted) return;
                          inbox.refresh();
                        },
                        icon: Badge(
                          isLabelVisible:
                              context.watch<NotificationController>().unreadCount >
                                  0,
                          smallSize: 8,
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: LooksUi.ink,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => CustomerShellTabs.goTo(CustomerShellTabs.profile),
                        child: StylAvatar(
                          size: 36,
                          imageUrl: user?.avatarUrl,
                          name: user?.fullName ?? 'You',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickLocation,
                        borderRadius: BorderRadius.circular(20),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 18,
                              color: LooksUi.ink,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: LooksUi.ink,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: LooksUi.ink,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _useCurrentLocation,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: LooksUi.hairline),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.near_me_outlined, size: 14, color: LooksUi.ink),
                            SizedBox(width: 6),
                            Text(
                              'Use current location',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: LooksUi.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _HeroSearch(
                controller: _search,
                onSearch: () => _openSearch(),
                onCamera: () => _pickLookPhoto(camera: true),
                onSearchServices: () {
                  Navigator.of(context).pushNamed(AppRoutes.searchServices);
                },
                onBrowseLooks: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.chooseLook,
                    arguments: ChooseLookArgs(categoryId: firstCategoryId),
                  );
                },
                onUploadPhoto: () => _pickLookPhoto(),
                imageUrl: heroUrl,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 0,
                  mainAxisExtent: 82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final c = homeCats[i];
                    return _CategoryTile(
                      category: c,
                      onTap: () => _openCategory(c),
                    );
                  },
                  childCount: homeCats.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Popular looks near you',
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 10),
                onSeeAll: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.chooseLook,
                    arguments: ChooseLookArgs(categoryId: firstCategoryId),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 186,
                child: popular.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Looks appear here from salon services.',
                          style: TextStyle(color: LooksUi.muted),
                        ),
                      )
                    : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: popular.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final look = popular[i];
                    return _PopularLookCard(
                      look: look,
                      onTap: () => _openLook(look),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FindLookCard(
                        looks: popular,
                        onUpload: () => _pickLookPhoto(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _NearbyMapCard(
                        shops: featured,
                        location: _location,
                        onViewMap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.nearbyMap,
                            arguments: const NearbyMapArgs(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Top rated professionals',
                onSeeAll: () {
                  if (firstLookId == null) return;
                  Navigator.of(context).pushNamed(
                    AppRoutes.findProfessionals,
                    arguments: FindProfessionalsArgs(lookId: firstLookId),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 248,
                child: featured.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Text(
                            'Professionals appear here once shops are nearby.',
                            style: TextStyle(color: LooksUi.muted, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        scrollDirection: Axis.horizontal,
                        itemCount: featured.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final shop = featured[i];
                          var thumbs = auth.marketplaceLooks
                              .where((l) => l.shopIds.contains(shop.id))
                              .take(3)
                              .toList();
                          if (thumbs.isEmpty) {
                            thumbs = popular.take(3).toList();
                          }
                          return _ProCard(
                            shop: shop,
                            lookThumbs: thumbs,
                            onTap: () => _openShop(shop),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroSearch extends StatelessWidget {
  const _HeroSearch({
    required this.controller,
    required this.onSearch,
    required this.onCamera,
    required this.onSearchServices,
    required this.onBrowseLooks,
    required this.onUploadPhoto,
    this.imageUrl,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onCamera;
  final VoidCallback onSearchServices;
  final VoidCallback onBrowseLooks;
  final VoidCallback onUploadPhoto;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Stack(
        children: [
          Positioned.fill(
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.2, -0.2),
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: LooksUi.ink),
                  )
                : const ColoredBox(color: LooksUi.ink),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xCC1A1633),
                    Color(0x661A1633),
                    Color(0x22000000),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Text(
                        'Find the exact\nlook you want.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.12,
                        child: Text(
                          'Good Hair\nBrighter Days',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: 12,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Find someone nearby who can do it.\nBook instantly.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  readOnly: true,
                  textInputAction: TextInputAction.search,
                  onTap: onSearch,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(fontSize: 14, color: LooksUi.ink),
                  decoration: InputDecoration(
                    hintText: 'What do you want done today?',
                    hintStyle: const TextStyle(
                      color: LooksUi.muted,
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: LooksUi.muted,
                    ),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: IconButton(
                        onPressed: onCamera,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x1A6B4EFF),
                          foregroundColor: LooksUi.purple,
                        ),
                        icon: const Icon(Icons.photo_camera_rounded),
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _HeroActionPill(
                        icon: Icons.notes_rounded,
                        label: 'Search services',
                        onTap: onSearchServices,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroActionPill(
                        icon: Icons.photo_library_outlined,
                        label: 'Browse looks',
                        onTap: onBrowseLooks,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroActionPill(
                        icon: Icons.photo_camera_outlined,
                        label: 'Upload a photo',
                        onTap: onUploadPhoto,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionPill extends StatelessWidget {
  const _HeroActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: LooksUi.ink),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: LooksUi.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final LookCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          LooksyCategoryIcon(categoryId: category.id, size: 52),
          const SizedBox(height: 4),
          Text(
            category.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: LooksUi.ink,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onSeeAll,
    this.padding = const EdgeInsets.fromLTRB(16, 18, 8, 12),
  });

  final String title;
  final VoidCallback onSeeAll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: LooksUi.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Row(
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    color: LooksUi.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: LooksUi.purple, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularLookCard extends StatelessWidget {
  const _PopularLookCard({required this.look, required this.onTap});

  final StyleLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 118,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LookPhoto(
                url: look.imageUrl,
                height: 118,
                width: 118,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              look.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: LooksUi.ink,
              ),
            ),
            Text(
              '${look.prosNearby} pros nearby',
              style: const TextStyle(fontSize: 12, color: LooksUi.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FindLookCard extends StatelessWidget {
  const _FindLookCard({required this.looks, required this.onUpload});

  final List<StyleLook> looks;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final photo = looks.isNotEmpty ? looks.first.imageUrl : null;
    return Container(
      height: 188,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 70, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Find This Look',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.15,
                    color: LooksUi.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Upload a photo and we’ll find matching professionals near you.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Color(0xFF5C5680),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 28,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LookPhoto(url: photo, width: 56, height: 70),
                ),
              ),
            ),
          ),
          Positioned(
            left: 44,
            bottom: 46,
            width: 44,
            height: 32,
            child: CustomPaint(painter: _SwooshArrowPainter()),
          ),
          Positioned(
            left: 10,
            bottom: 42,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 0,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onUpload,
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.photo_camera_outlined,
                    color: LooksUi.purple,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: onUpload,
                style: FilledButton.styleFrom(
                  backgroundColor: LooksUi.purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Upload a photo'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwooshArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LooksUi.purple
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(2, size.height - 4)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.15,
        size.width * 0.62,
        size.height * -0.05,
        size.width - 3,
        size.height * 0.28,
      );
    canvas.drawPath(path, paint);

    final tip = Offset(size.width - 3, size.height * 0.28);
    final head = Paint()
      ..color = LooksUi.purple
      ..style = PaintingStyle.fill;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx + 1, tip.dy)
        ..lineTo(tip.dx - 7, tip.dy - 4.5)
        ..lineTo(tip.dx - 6, tip.dy + 5)
        ..close(),
      head,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NearbyMapCard extends StatelessWidget {
  const _NearbyMapCard({
    required this.shops,
    required this.location,
    required this.onViewMap,
  });

  final List<ShopDto> shops;
  final String location;
  final VoidCallback onViewMap;

  static const _pinSpots = <Alignment>[
    Alignment(-0.55, 0.12),
    Alignment(0.38, -0.22),
    Alignment(0.82, 0.18),
  ];

  @override
  Widget build(BuildContext context) {
    final pins = shops.take(3).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 188,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              LooksUi.mapImage,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: Color(0xFFD7E8F0),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE6F3FBFD),
                    Color(0x99F3FBFD),
                    Color(0x33FFFFFF),
                    Color(0x66FFFFFF),
                  ],
                  stops: [0, 0.32, 0.62, 1],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.08, 0.18),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: LooksUi.purple.withValues(alpha: 0.14),
                  border: Border.all(
                    color: LooksUi.purple.withValues(alpha: 0.28),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const Align(
              alignment: Alignment(0.08, 0.18),
              child: Icon(Icons.location_on, color: LooksUi.purple, size: 26),
            ),
            for (var i = 0; i < pins.length; i++)
              Align(
                alignment: _pinSpots[i],
                child: _MapFace(shop: pins[i]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Professionals near you',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      height: 1.15,
                      color: Color(0xFF1E4F8A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'See top-rated pros around $location.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Color(0xFF3E6A96),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Material(
                      color: Colors.white,
                      elevation: 3,
                      shadowColor: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: onViewMap,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: LooksUi.purple,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'View on map',
                                style: TextStyle(
                                  color: LooksUi.purple,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFace extends StatelessWidget {
  const _MapFace({required this.shop});

  final ShopDto shop;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        image: shop.hasPhoto
            ? DecorationImage(
                image: NetworkImage(shop.imageUrl),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: shop.hasPhoto
          ? null
          : Text(
              shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: LooksUi.ink,
              ),
            ),
    );
  }
}

class _ProCard extends StatefulWidget {
  const _ProCard({
    required this.shop,
    required this.lookThumbs,
    required this.onTap,
  });

  final ShopDto shop;
  final List<StyleLook> lookThumbs;
  final VoidCallback onTap;

  @override
  State<_ProCard> createState() => _ProCardState();
}

class _ProCardState extends State<_ProCard> {
  var _saved = false;

  @override
  void initState() {
    super.initState();
    SessionStore().isShopSaved(widget.shop.id).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  Future<void> _toggle() async {
    final next = !_saved;
    setState(() => _saved = next);
    await SessionStore().setShopSaved(widget.shop.id, next);
    final owner = widget.shop.ownerUserId;
    if (next && owner != null && owner.isNotEmpty) {
      await SessionStore().setBarberSaved(owner, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final rating = shop.ratingAvg;
    final count = shop.ratingCount;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 158,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    shop.imageUrl,
                    height: 108,
                    width: 158,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: LooksUi.cream,
                      child: SizedBox(height: 108, width: 158),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: _toggle,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white,
                      child: Icon(
                        _saved ? Icons.favorite_rounded : Icons.favorite_border,
                        size: 16,
                        color: _saved ? LooksUi.purple : LooksUi.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            VerifiedSalonName(
              name: shop.name,
              isVerified: shop.isVerified,
              badgeSize: 14,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: LooksUi.ink,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5B400)),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    count > 0
                        ? '${rating.toStringAsFixed(1)} ($count)'
                        : 'New',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: LooksUi.ink,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              [
                shop.distanceLabel,
                if ((shop.area ?? '').isNotEmpty) shop.area!,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: LooksUi.muted),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < 3 && i < widget.lookThumbs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LookPhoto(
                      url: widget.lookThumbs[i].imageUrl,
                      width: 36,
                      height: 36,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
