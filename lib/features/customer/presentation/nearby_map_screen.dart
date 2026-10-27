import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../data/looks_catalog.dart';
import 'available_today_screen.dart';
import 'looks_ui.dart';

class NearbyMapArgs {
  const NearbyMapArgs({this.lookId, this.lookName});

  final String? lookId;
  final String? lookName;
}

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key, this.args = const NearbyMapArgs()});

  final NearbyMapArgs args;

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final _map = MapController();
  var _showMap = true;
  ShopDto? _selected;
  final Map<String, List<SpecialistDto>> _teams = {};
  final Set<String> _teamLoads = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final auth = context.read<AuthController>();
    if (auth.marketplaceShops.isEmpty) {
      await auth.loadMarketplace(force: true);
    }
    if (!mounted) return;
    for (final shop in _shops(auth)) {
      unawaited(_loadTeam(shop.id));
    }
  }

  List<ShopDto> _shops(AuthController auth) {
    final lookId = widget.args.lookId;
    var shops = auth.marketplaceShops.where((s) => s.lat != null && s.lng != null);
    if (lookId != null) {
      final look = auth.lookById(lookId);
      if (look != null) {
        final ids = look.shopIds.toSet();
        shops = shops.where((s) => ids.contains(s.id));
      }
    }
    return shops.toList();
  }

  List<SpecialistDto> _team(String shopId) => _teams[shopId] ?? const [];

  Future<void> _loadTeam(String shopId) async {
    if (_teams.containsKey(shopId) || !_teamLoads.add(shopId)) return;
    try {
      final team = await context.read<AuthController>().catalogApi
          .listSpecialists(shopId);
      if (!mounted) return;
      setState(() => _teams[shopId] = team);
    } catch (_) {
      if (!mounted) return;
      setState(() => _teams[shopId] = const []);
    } finally {
      _teamLoads.remove(shopId);
    }
  }

  void _select(ShopDto shop) {
    setState(() => _selected = shop);
    unawaited(_loadTeam(shop.id));
    if (shop.lat != null && shop.lng != null) {
      _map.move(LatLng(shop.lat!, shop.lng!), 14.5);
    }
  }

  void _openShop(ShopDto shop) {
    Navigator.of(context).pushNamed(
      AppRoutes.providerDetail,
      arguments: ProviderDetailArgs(
        shopId: shop.id,
        name: shop.name,
        subtitle: widget.args.lookName ?? shop.areaLabel,
        rating: shop.ratingAvg,
        distance: shop.distanceLabel,
        address: shop.addressLine,
        imageUrl: shop.imageUrl,
        description: shop.description,
        lookName: widget.args.lookName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final shops = _shops(auth);
    final selected = _selected ?? (shops.isNotEmpty ? shops.first : null);
    final origin = shops.isNotEmpty
        ? LatLng(shops.first.lat!, shops.first.lng!)
        : const LatLng(51.4123, -0.3007);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        iconTheme: const IconThemeData(color: LooksUi.toolbar),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Salons near you',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Available times',
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.availableToday,
                arguments: AvailableTodayArgs(
                  lookId: widget.args.lookId,
                  lookName: widget.args.lookName,
                ),
              );
            },
            icon: const Icon(Icons.event_available_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: LooksUi.searchFill,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  _ModeTab(
                    label: 'List',
                    selected: !_showMap,
                    onTap: () => setState(() => _showMap = false),
                  ),
                  _ModeTab(
                    label: 'Map',
                    selected: _showMap,
                    onTap: () => setState(() => _showMap = true),
                  ),
                ],
              ),
            ),
          ),
          if (widget.args.lookName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Only salons that list ${widget.args.lookName} on STYL.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: LooksUi.muted, fontSize: 13),
              ),
            ),
          Expanded(
            child: shops.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: auth.marketplaceLoading
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  auth.marketplaceError ??
                                      'No mapped salons nearby for this style yet.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: LooksUi.muted),
                                ),
                                TextButton(
                                  onPressed: () => auth.loadMarketplace(
                                    force: true,
                                  ),
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                    ),
                  )
                : _showMap
                    ? Stack(
                        children: [
                          FlutterMap(
                            mapController: _map,
                            options: MapOptions(
                              initialCenter: selected != null
                                  ? LatLng(selected.lat!, selected.lng!)
                                  : origin,
                              initialZoom: 13.2,
                              onTap: (_, _) {},
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.stylaus.app',
                                tileProvider: NetworkTileProvider(
                                  cachingProvider:
                                      const DisabledMapCachingProvider(),
                                ),
                              ),
                              SimpleAttributionWidget(
                                source: const Text(
                                  'OpenStreetMap · CARTO',
                                  style: TextStyle(fontSize: 11),
                                ),
                                alignment: Alignment.bottomLeft,
                              ),
                              MarkerLayer(
                                markers: [
                                  for (final shop in shops)
                                    Marker(
                                      point: LatLng(shop.lat!, shop.lng!),
                                      width: 40,
                                      height: 40,
                                      child: GestureDetector(
                                        onTap: () => _select(shop),
                                        child: Icon(
                                          Icons.location_on,
                                          size: 38,
                                          color: shop.id == selected?.id
                                              ? LooksUi.purple
                                              : const Color(0xFFE85D5D),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            right: 16,
                            top: 16,
                            child: Material(
                              color: Colors.white,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: IconButton(
                                onPressed: selected == null
                                    ? null
                                    : () => _select(selected),
                                icon: const Icon(
                                  Icons.near_me_rounded,
                                  color: LooksUi.ink,
                                ),
                              ),
                            ),
                          ),
                          if (selected != null)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: _SalonSheet(
                                shop: selected,
                                team: _team(selected.id),
                                onView: () => _openShop(selected),
                              ),
                            ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: shops.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final shop = shops[i];
                          return _SalonSheet(
                            shop: shop,
                            team: _team(shop.id),
                            onView: () => _openShop(shop),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? LooksUi.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : LooksUi.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SalonSheet extends StatelessWidget {
  const _SalonSheet({
    required this.shop,
    required this.team,
    required this.onView,
  });

  final ShopDto shop;
  final List<SpecialistDto> team;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: LookPhoto(url: shop.hasPhoto ? shop.imageUrl : null),
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
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF5B400),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            shop.ratingLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: LooksUi.ink,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        shop.distanceLabel,
                        style: const TextStyle(
                          color: LooksUi.muted,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        shop.openStatusLabel,
                        style: TextStyle(
                          color: shop.openStatusLabel.startsWith('Open')
                              ? const Color(0xFF1B8A4A)
                              : LooksUi.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (team.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: team.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final pro = team[i];
                    return StylAvatar(
                      size: 48,
                      imageUrl: pro.avatarUrl,
                      name: pro.displayName,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: onView,
                style: FilledButton.styleFrom(
                  backgroundColor: LooksUi.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'View salon',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
