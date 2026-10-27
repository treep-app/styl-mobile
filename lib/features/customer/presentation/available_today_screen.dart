import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/verified_badge.dart';
import '../data/looks_catalog.dart';
import '../data/salon_filters.dart';
import 'looks_ui.dart';
import 'results_filter_screen.dart';
import 'save_heart_button.dart';

class AvailableTodayArgs {
  const AvailableTodayArgs({this.lookId, this.lookName});

  final String? lookId;
  final String? lookName;
}

/// Looksy Available Today — real bookable slots for nearby salons.
class AvailableTodayScreen extends StatefulWidget {
  const AvailableTodayScreen({super.key, this.args = const AvailableTodayArgs()});

  final AvailableTodayArgs args;

  @override
  State<AvailableTodayScreen> createState() => _AvailableTodayScreenState();
}

class _AvailableTodayScreenState extends State<AvailableTodayScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  late final DateTime _today;
  late final List<DateTime> _days;
  late DateTime _selected;
  var _filters = SalonFilters.defaults;
  var _loading = true;
  String? _error;
  List<AvailabilityShopDto> _rows = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _days = List.generate(4, (i) => _today.add(Duration(days: i)));
    _selected = _today;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _chipTitle(DateTime day) {
    if (_sameDay(day, _today)) return 'Today';
    if (_sameDay(day, _today.add(const Duration(days: 1)))) return 'Tomorrow';
    return _weekdays[day.weekday - 1];
  }

  String _chipSubtitle(DateTime day) => '${day.day} ${_months[day.month - 1]}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    try {
      final result = await auth.catalogApi.listAvailability(
        date: _ymd(_selected),
        lookId: widget.args.lookId,
        area: auth.marketplaceArea,
      );
      if (!mounted) return;
      setState(() {
        _rows = result.shops;
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

  List<AvailabilityShopDto> get _visible => _filters.apply(_rows);

  Future<void> _openFilters() async {
    final next = await Navigator.of(context).pushNamed(
      AppRoutes.filterResults,
      arguments: FilterResultsArgs(
        initial: _filters,
        results: _rows,
        dateIsToday: _sameDay(_selected, _today),
      ),
    );
    if (!mounted || next is! SalonFilters) return;
    setState(() => _filters = next);
  }

  void _openShop(AvailabilityShopDto row) {
    final lookName = widget.args.lookName;
    Navigator.of(context).pushNamed(
      AppRoutes.providerDetail,
      arguments: ProviderDetailArgs(
        shopId: row.shop.id,
        name: row.shop.name,
        subtitle: lookName ?? row.shop.areaLabel,
        rating: row.shop.ratingAvg,
        distance: row.shop.distanceLabel,
        address: row.shop.addressLine,
        imageUrl: row.shop.hasPhoto ? row.shop.imageUrl : null,
        description: row.shop.description,
        barberUserId: row.slots.isNotEmpty
            ? row.slots.first.barberUserId
            : row.shop.ownerUserId,
        lookName: lookName,
      ),
    );
  }

  void _book(AvailabilityShopDto row, SlotDto slot) {
    Navigator.of(context).pushNamed(
      AppRoutes.looksBook,
      arguments: LooksBookArgs(
        shopId: row.shop.id,
        salonName: row.shop.name,
        address: row.shop.addressLine,
        imageUrl: row.shop.hasPhoto ? row.shop.imageUrl : null,
        barberUserId: slot.barberUserId ?? row.shop.ownerUserId,
        lookName: widget.args.lookName,
        rating: row.shop.ratingAvg,
        distance: row.shop.distanceLabel,
        preferredDate: _selected,
        preferredSlotStartAt: slot.startAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

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
          'Available Today',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _loading ? null : _openFilters,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 86,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              scrollDirection: Axis.horizontal,
              itemCount: _days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final day = _days[i];
                final selected = _sameDay(day, _selected);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selected = day;
                      if (!_sameDay(day, _today)) {
                        _filters = _filters.copyWith(openNow: false);
                      }
                    });
                    _load();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 86,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? LooksUi.purple : LooksUi.searchFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _chipTitle(day),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : LooksUi.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _chipSubtitle(day),
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : LooksUi.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
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
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : visible.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'No bookable times on this day. Try another date or loosen filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: LooksUi.muted, height: 1.4),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 18),
                              itemBuilder: (context, i) {
                                final row = visible[i];
                                return _SalonAvailabilityCard(
                                  row: row,
                                  onOpen: () => _openShop(row),
                                  onSlot: (slot) => _book(row, slot),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _SalonAvailabilityCard extends StatelessWidget {
  const _SalonAvailabilityCard({
    required this.row,
    required this.onOpen,
    required this.onSlot,
  });

  final AvailabilityShopDto row;
  final VoidCallback onOpen;
  final ValueChanged<SlotDto> onSlot;

  @override
  Widget build(BuildContext context) {
    final shop = row.shop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: LookPhoto(url: shop.hasPhoto ? shop.imageUrl : null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VerifiedSalonName(
                      name: shop.name,
                      isVerified: row.isVerified || shop.isVerified,
                      badgeSize: 17,
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
                      shop.distanceLabel,
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (row.slots.isEmpty)
          const Text(
            'No times this day',
            style: TextStyle(color: LooksUi.muted, fontWeight: FontWeight.w600),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final slot in row.slots.take(3))
                GestureDetector(
                  onTap: () => onSlot(slot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: LooksUi.searchFill,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      slot.displayLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: LooksUi.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
