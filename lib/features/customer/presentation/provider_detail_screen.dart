import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/utils/open_link.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../data/looks_catalog.dart';
import 'looks_ui.dart';
import 'salon_professionals_screen.dart';
import 'save_heart_button.dart';
import '../../../core/widgets/verified_badge.dart';

/// Looksy Salon Profile — cover, hours, overview / services / team / reviews.
class ProviderDetailScreen extends StatefulWidget {
  const ProviderDetailScreen({super.key, required this.args});

  final ProviderDetailArgs args;

  @override
  State<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends State<ProviderDetailScreen> {
  late ProviderDetailArgs _args;
  ShopDto? _shop;
  List<SpecialistDto> _team = const [];
  var _tab = 0;
  var _saved = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _args = widget.args;
    SessionStore().isShopSaved(_args.shopId).then((v) {
      if (mounted) setState(() => _saved = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_args.shopId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final auth = context.read<AuthController>();
    try {
      final shop = await auth.catalogApi.getShop(_args.shopId);
      final team = await auth.catalogApi.listSpecialists(_args.shopId);
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _team = team;
        _loading = false;
        _args = ProviderDetailArgs(
          shopId: shop.id,
          name: shop.name,
          subtitle: _args.subtitle,
          rating: shop.ratingAvg == 0 ? _args.rating : shop.ratingAvg,
          distance: shop.distanceKm != null
              ? shop.distanceLabel
              : _args.distance,
          address:
              shop.addressLine.isNotEmpty ? shop.addressLine : _args.address,
          imageUrl: shop.hasPhoto ? shop.coverImageUrl : _args.imageUrl,
          description: shop.description ?? _args.description,
          barberUserId: _args.barberUserId ?? shop.ownerUserId,
          lookName: _args.lookName,
          lookImageUrl: _args.lookImageUrl,
        );
      });
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave() async {
    final next = !_saved;
    setState(() => _saved = next);
    await SessionStore().setShopSaved(_args.shopId, next);
    final barber = _args.barberUserId ?? _shop?.ownerUserId;
    if (next && barber != null && barber.isNotEmpty) {
      await SessionStore().setBarberSaved(barber, true);
    }
  }

  String get _imageUrl {
    // Prefer cover for the hero; fall back to logo / profile photo.
    if (_shop != null && _shop!.hasPhoto) {
      final cover = _shop!.coverImageUrl;
      if (cover.isNotEmpty) return cover;
      return _shop!.profileImageUrl;
    }
    final url = _args.imageUrl;
    if (url != null && url.trim().isNotEmpty) return url;
    return '';
  }

  String get _bio {
    final d = (_shop?.description ?? _args.description)?.trim();
    if (d != null && d.isNotEmpty) return d;
    return '${_args.name} is listed on STYL.';
  }

  String get _place {
    final area = (_shop?.area ?? '').trim();
    if (area.isNotEmpty) return area;
    return _args.address;
  }

  String get _hoursLabel =>
      _shop?.openStatusLabel ?? _shop?.hoursLabel ?? 'Hours not listed';

  Future<void> _openUrl(Uri uri) async {
    final ok = await openExternalUri(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  Future<void> _call() async {
    final phone = (_shop?.phone ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number listed for this salon.')),
      );
      return;
    }
    await _openUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _directions() async {
    final shop = _shop;
    final uri = shop?.lat != null && shop?.lng != null
        ? Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${shop!.lat},${shop.lng}',
          )
        : Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_args.address)}',
          );
    await _openUrl(uri);
  }

  Future<void> _website() async {
    var site = (_shop?.website ?? '').trim();
    if (site.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No website listed for this salon.')),
      );
      return;
    }
    if (!site.startsWith('http://') && !site.startsWith('https://')) {
      site = 'https://$site';
    }
    await _openUrl(Uri.parse(site));
  }

  Future<void> _share() async {
    final text = '${_args.name}\n$_place\n${_args.address}';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salon details copied.')),
    );
  }

  void _viewProfessionals() {
    if (_args.shopId.isEmpty) return;
    Navigator.of(context).pushNamed(
      AppRoutes.salonProfessionals,
      arguments: SalonProfessionalsArgs(
        shopId: _args.shopId,
        salonName: _args.name,
        address: _args.address,
        imageUrl: _imageUrl,
        lookName: _args.lookName,
        lookImageUrl: _args.lookImageUrl,
        rating: _args.rating,
        distance: _args.distance,
      ),
    );
  }

  void _book({SpecialistDto? pro, ServiceDto? service}) {
    Navigator.of(context).pushNamed(
      AppRoutes.looksBook,
      arguments: LooksBookArgs(
        shopId: _args.shopId,
        salonName: _args.name,
        address: _args.address,
        imageUrl: _imageUrl,
        barberUserId: pro?.id ?? _args.barberUserId ?? _shop?.ownerUserId,
        lookName: service?.name ?? _args.lookName ?? _args.subtitle,
        lookImageUrl: _args.lookImageUrl ?? _imageUrl,
        rating: _args.rating,
        distance: _args.distance,
        serviceId: service?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final rating = _shop?.ratingAvg ?? _args.rating;
    final reviews = _shop?.ratingCount ?? 0;
    final openNow = _hoursLabel.startsWith('Open');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: LooksUi.toolbar),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Salon Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: LooksUi.toolbar,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _shop == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      _CoverPhoto(
                        url: _imageUrl,
                        saved: _saved,
                        showPin: _shop?.lat != null && _shop?.lng != null,
                        onSave: _toggleSave,
                        onShare: _share,
                        onPin: _directions,
                      ),
                      const SizedBox(height: 16),
                      VerifiedSalonName(
                        name: _args.name,
                        isVerified: _shop?.isVerified == true,
                        badgeSize: 22,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: LooksUi.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFF5B400),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reviews > 0
                                ? '${rating.toStringAsFixed(1)} ($reviews reviews)'
                                : 'New on STYL',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: LooksUi.ink,
                            ),
                          ),
                          if (_shop?.isVerified == true) ...[
                            const SizedBox(width: 10),
                            const VerifiedBadge(size: 14, showLabel: true),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_args.distance} · $_place',
                        style: const TextStyle(
                          color: LooksUi.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _hoursLabel,
                        style: TextStyle(
                          color: openNow
                              ? const Color(0xFF1B8A4A)
                              : LooksUi.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SalonTabs(
                        index: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      const SizedBox(height: 16),
                      if (_tab == 0) ...[
                        Text(
                          _bio,
                          style: const TextStyle(
                            color: LooksUi.muted,
                            height: 1.45,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            _ActionIcon(
                              icon: Icons.phone_outlined,
                              label: 'Call',
                              onTap: _call,
                            ),
                            _ActionIcon(
                              icon: Icons.near_me_outlined,
                              label: 'Directions',
                              onTap: _directions,
                            ),
                            _ActionIcon(
                              icon: Icons.language_outlined,
                              label: 'Website',
                              onTap: _website,
                            ),
                            _ActionIcon(
                              icon: Icons.ios_share_rounded,
                              label: 'Share',
                              onTap: _share,
                            ),
                          ],
                        ),
                      ] else if (_tab == 1)
                        _ServicesTab(
                          services: _shop?.services ?? const [],
                          onBook: (s) => _book(service: s),
                        )
                      else if (_tab == 2)
                        _TeamTab(
                          team: _team,
                          onBook: (p) => _book(pro: p),
                          onSeeAll: _viewProfessionals,
                        )
                      else
                        _ReviewsTab(rating: rating, count: reviews),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: _viewProfessionals,
                style: FilledButton.styleFrom(
                  backgroundColor: LooksUi.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'View professionals',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({
    required this.url,
    required this.saved,
    required this.showPin,
    required this.onSave,
    required this.onShare,
    required this.onPin,
  });

  final String url;
  final bool saved;
  final bool showPin;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 188,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LookPhoto(url: url.isEmpty ? null : url),
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _CoverIcon(icon: Icons.ios_share_rounded, onTap: onShare),
                  const SizedBox(width: 8),
                  _CoverIcon(
                    icon: saved ? Icons.favorite_rounded : Icons.favorite_border,
                    color: saved ? savedHeartColor : LooksUi.ink,
                    onTap: onSave,
                  ),
                ],
              ),
            ),
            if (showPin)
              Positioned(
                left: 10,
                bottom: 10,
                child: GestureDetector(
                  onTap: onPin,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF2BB673),
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoverIcon extends StatelessWidget {
  const _CoverIcon({
    required this.icon,
    required this.onTap,
    this.color = LooksUi.ink,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _SalonTabs extends StatelessWidget {
  const _SalonTabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Overview', 'Services', 'Team', 'Reviews'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              child: Column(
                children: [
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: index == i ? LooksUi.ink : LooksUi.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: index == i ? LooksUi.purple : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Icon(icon, color: LooksUi.purple, size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: LooksUi.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.services, required this.onBook});

  final List<ServiceDto> services;
  final ValueChanged<ServiceDto> onBook;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Text(
        'Services will appear here once this salon adds them.',
        style: TextStyle(color: LooksUi.muted, height: 1.4),
      );
    }
    return Column(
      children: [
        for (final s in services)
          InkWell(
            onTap: () => onBook(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: LooksUi.ink,
                          ),
                        ),
                        Text(
                          '${s.durationMin} mins',
                          style: const TextStyle(
                            color: LooksUi.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    s.priceLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LooksUi.ink,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: LooksUi.muted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TeamTab extends StatelessWidget {
  const _TeamTab({
    required this.team,
    required this.onBook,
    required this.onSeeAll,
  });

  final List<SpecialistDto> team;
  final ValueChanged<SpecialistDto> onBook;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (team.isEmpty) {
      return const Text(
        'No team members listed yet.',
        style: TextStyle(color: LooksUi.muted, height: 1.4),
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: LooksUi.purple,
              ),
            ),
          ),
        ),
        for (final p in team)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                StylAvatar(
                  size: 52,
                  imageUrl: p.avatarUrl,
                  name: p.fullName ?? 'Professional',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (p.fullName ?? '').trim().isEmpty
                            ? 'Professional'
                            : p.fullName!.trim(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: LooksUi.ink,
                        ),
                      ),
                      Text(
                        p.roleSpecialtyLabel,
                        style: const TextStyle(
                          color: LooksUi.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onBook(p),
                  child: const Text(
                    'Book',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: LooksUi.purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF5B400), size: 22),
            const SizedBox(width: 6),
            Text(
              count > 0
                  ? '${rating.toStringAsFixed(1)} · $count reviews on STYL'
                  : 'No reviews yet',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: LooksUi.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          count > 0
              ? 'These ratings come from people who booked this salon on STYL. Written comments stay on the booking they reviewed.'
              : 'Be the first to leave a review after a completed appointment.',
          style: const TextStyle(color: LooksUi.muted, height: 1.45),
        ),
      ],
    );
  }
}
