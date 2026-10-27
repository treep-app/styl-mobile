import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import 'looks_ui.dart';
import 'save_heart_button.dart';

class SalonProfessionalsArgs {
  const SalonProfessionalsArgs({
    required this.shopId,
    required this.salonName,
    required this.address,
    this.imageUrl,
    this.lookName,
    this.lookImageUrl,
    this.rating = 0,
    this.distance = 'Nearby',
  });

  final String shopId;
  final String salonName;
  final String address;
  final String? imageUrl;
  final String? lookName;
  final String? lookImageUrl;
  final double rating;
  final String distance;
}

enum _ProFilter { all, barber, stylist }

/// Looksy Professionals at this salon — real team, next bookable slot, Book.
class SalonProfessionalsScreen extends StatefulWidget {
  const SalonProfessionalsScreen({super.key, required this.args});

  final SalonProfessionalsArgs args;

  @override
  State<SalonProfessionalsScreen> createState() =>
      _SalonProfessionalsScreenState();
}

class _SalonProfessionalsScreenState extends State<SalonProfessionalsScreen> {
  var _filter = _ProFilter.all;
  var _loading = true;
  String? _error;
  ShopDto? _shop;
  List<SpecialistDto> _team = const [];
  final Map<String, SlotDto?> _next = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool _isStylist(SpecialistDto p) {
    final s = '${p.specialty ?? ''} ${p.roleSpecialtyLabel}'.toLowerCase();
    return s.contains('stylist') ||
        s.contains('colour') ||
        s.contains('color') ||
        s.contains('blow') ||
        s.contains('women');
  }

  bool _isBarber(SpecialistDto p) {
    if (_isStylist(p)) return false;
    final s = (p.specialty ?? '').toLowerCase();
    if (s.contains('nail') ||
        s.contains('lash') ||
        s.contains('brow') ||
        s.contains('beauty') ||
        s.contains('skin')) {
      return false;
    }
    return s.contains('barber') ||
        s.contains('fade') ||
        s.contains('beard') ||
        s.contains('taper') ||
        s.contains('cut') ||
        s.isEmpty;
  }

  List<SpecialistDto> get _visible {
    switch (_filter) {
      case _ProFilter.all:
        return _team;
      case _ProFilter.barber:
        return _team.where(_isBarber).toList();
      case _ProFilter.stylist:
        return _team.where(_isStylist).toList();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    try {
      final shop = await auth.catalogApi.getShop(widget.args.shopId);
      final today = _ymd(DateTime.now());
      final team = await auth.catalogApi.listSpecialists(
        widget.args.shopId,
        date: today,
      );
      if (!mounted) return;
      final next = <String, SlotDto?>{};
      for (final p in team) {
        if (p.nextSlot != null) next[p.id] = p.nextSlot;
      }
      setState(() {
        _shop = shop;
        _team = team;
        _next
          ..clear()
          ..addAll(next);
        _loading = false;
      });
      final missing = team.where((p) => p.nextSlot == null).toList();
      if (missing.isNotEmpty) await _loadNextSlots(missing);
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

  Future<void> _loadNextSlots(List<SpecialistDto> team) async {
    final api = context.read<AuthController>().catalogApi;
    final now = DateTime.now();
    await Future.wait(
      team.map((p) async {
        SlotDto? next;
        for (var i = 0; i < 3 && next == null; i++) {
          final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
          try {
            final slots = await api.listSlots(barberId: p.id, date: _ymd(day));
            for (final s in slots) {
              if (!s.available) continue;
              final start = DateTime.tryParse(s.startAt);
              if (start != null && start.isAfter(now)) {
                next = s;
                break;
              }
            }
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() => _next[p.id] = next);
      }),
    );
  }

  String? _nextLabel(SlotDto? slot) {
    if (slot == null) return null;
    final start = DateTime.tryParse(slot.startAt)?.toLocal();
    if (start == null) return 'Next: ${slot.displayLabel}';
    final today = DateTime.now();
    final startDay = DateTime(start.year, start.month, start.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    if (startDay == todayDay) return 'Next: ${slot.displayLabel}';
    if (startDay == todayDay.add(const Duration(days: 1))) {
      return 'Next: Tomorrow ${slot.displayLabel}';
    }
    return 'Next: ${slot.displayLabel}';
  }

  String _skills(SpecialistDto p) {
    final look = (widget.args.lookName ?? '').trim();
    final fromApi = p.serviceNames
        .map((s) => s.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final fromShop = (_shop?.services ?? const <ServiceDto>[])
        .map((s) => s.name.trim())
        .where((n) => n.isNotEmpty)
        .toList();
    final tags = <String>[];
    if (look.isNotEmpty) tags.add(look);
    final specialty = (p.specialty ?? '').trim();
    if (specialty.isNotEmpty &&
        !tags.any((t) => t.toLowerCase() == specialty.toLowerCase())) {
      tags.add(specialty);
    }
    for (final name in [...fromApi, ...fromShop]) {
      if (tags.length >= 2) break;
      if (tags.any((t) => t.toLowerCase() == name.toLowerCase())) continue;
      tags.add(name);
    }
    return tags.take(2).join(' · ');
  }

  void _book(SpecialistDto p) {
    final slot = _next[p.id];
    DateTime? preferred;
    if (slot != null) {
      preferred = DateTime.tryParse(slot.startAt)?.toLocal();
      if (preferred != null) {
        preferred = DateTime(preferred.year, preferred.month, preferred.day);
      }
    }
    Navigator.of(context).pushNamed(
      AppRoutes.looksBook,
      arguments: LooksBookArgs(
        shopId: widget.args.shopId,
        salonName: widget.args.salonName,
        address: widget.args.address,
        imageUrl: widget.args.imageUrl ?? _shop?.imageUrl,
        barberUserId: p.id,
        lookName: widget.args.lookName,
        lookImageUrl: widget.args.lookImageUrl,
        rating: _shop?.ratingAvg ?? widget.args.rating,
        distance: widget.args.distance,
        preferredDate: preferred,
        preferredSlotStartAt: slot?.startAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barbers = _team.where(_isBarber).length;
    final stylists = _team.where(_isStylist).length;
    final visible = _visible;
    final rating = _shop?.ratingAvg ?? widget.args.rating;
    final reviews = _shop?.ratingCount ?? 0;

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
          'Professionals at this salon',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: LooksUi.muted),
                        ),
                        TextButton(onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Text(
                      widget.args.salonName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: LooksUi.ink,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'All (${_team.length})',
                            selected: _filter == _ProFilter.all,
                            onTap: () => setState(() => _filter = _ProFilter.all),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Barbers ($barbers)',
                            selected: _filter == _ProFilter.barber,
                            onTap: () =>
                                setState(() => _filter = _ProFilter.barber),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Stylists ($stylists)',
                            selected: _filter == _ProFilter.stylist,
                            onTap: () =>
                                setState(() => _filter = _ProFilter.stylist),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No professionals in this category yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: LooksUi.muted),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 18),
                              itemBuilder: (context, i) {
                                final p = visible[i];
                                final slot = _next.containsKey(p.id)
                                    ? _next[p.id]
                                    : null;
                                final waiting = !_next.containsKey(p.id);
                                return _ProRow(
                                  pro: p,
                                  skills: _skills(p),
                                  rating: p.ratingAvg ?? rating,
                                  reviews: p.ratingCount ?? reviews,
                                  nextLabel: waiting ? null : _nextLabel(slot),
                                  loadingNext: waiting,
                                  onBook: () => _book(p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            fontSize: 13,
            color: selected ? Colors.white : LooksUi.ink,
          ),
        ),
      ),
    );
  }
}

class _ProRow extends StatelessWidget {
  const _ProRow({
    required this.pro,
    required this.skills,
    required this.rating,
    required this.reviews,
    required this.onBook,
    this.nextLabel,
    this.loadingNext = false,
  });

  final SpecialistDto pro;
  final String skills;
  final double rating;
  final int reviews;
  final String? nextLabel;
  final bool loadingNext;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final name = (pro.fullName ?? '').trim().isEmpty
        ? 'Professional'
        : pro.fullName!.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StylAvatar(size: 64, imageUrl: pro.avatarUrl, name: name),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
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
                    reviews > 0
                        ? '${rating.toStringAsFixed(1)} ($reviews)'
                        : 'New',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: LooksUi.ink,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              if (skills.isNotEmpty)
                Text(
                  skills,
                  style: const TextStyle(color: LooksUi.muted, fontSize: 13),
                ),
              const SizedBox(height: 6),
              if (loadingNext)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (nextLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    nextLabel!,
                    style: const TextStyle(
                      color: Color(0xFF1B8A4A),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                const Text(
                  'No times today',
                  style: TextStyle(
                    color: LooksUi.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        Column(
          children: [
            SaveBarberHeart(barberUserId: pro.id),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onBook,
              style: FilledButton.styleFrom(
                backgroundColor: LooksUi.purple,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Book',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
