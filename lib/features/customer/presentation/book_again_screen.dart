import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../data/looks_catalog.dart';
import 'looks_ui.dart';
import 'save_heart_button.dart';

/// Looksy Book Again — completed visits, rebook in a tap.
class BookAgainScreen extends StatefulWidget {
  const BookAgainScreen({super.key});

  @override
  State<BookAgainScreen> createState() => _BookAgainScreenState();
}

class _BookAgainScreenState extends State<BookAgainScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  var _loading = true;
  String? _error;
  List<AppointmentDto> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _dateLabel(DateTime raw) {
    final d = raw.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final closed =
          await context.read<AuthController>().appointmentsApi.list(status: 'CLOSED');
      final completed = closed.where((a) => a.isCompleted).toList()
        ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
      if (!mounted) return;
      setState(() {
        _items = completed;
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

  String _photo(AppointmentDto a, AuthController auth) {
    if (a.shopImageUrl.isNotEmpty) return a.shopImageUrl;
    final shopId = a.shopId;
    if (shopId != null) {
      for (final shop in auth.marketplaceShops) {
        if (shop.id == shopId && shop.hasPhoto) return shop.imageUrl;
      }
    }
    return a.barberAvatar ?? '';
  }

  void _book(AppointmentDto a) {
    final shopId = a.shopId;
    if (shopId == null || shopId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This visit has no salon to rebook.')),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.looksBook,
      arguments: LooksBookArgs(
        shopId: shopId,
        salonName: a.shopName ?? 'Salon',
        address: a.shopAddress ?? '',
        imageUrl: a.shopImageUrl.isNotEmpty ? a.shopImageUrl : a.barberAvatar,
        barberUserId: a.barberUserId,
        lookName: a.serviceName,
        rating: 0,
        distance: 'Nearby',
        serviceId: a.serviceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

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
          'Book Again',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
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
              : RefreshIndicator(
                  color: LooksUi.purple,
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
                          children: const [
                            Icon(
                              Icons.event_available_outlined,
                              size: 40,
                              color: LooksUi.muted,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No previous bookings yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: LooksUi.ink,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Completed visits appear here so you can rebook the same salon and service.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: LooksUi.muted, height: 1.4),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 12, 28),
                          itemCount: _items.length + 1,
                          separatorBuilder: (_, i) => i == 0
                              ? const SizedBox(height: 12)
                              : const Divider(height: 1, color: Color(0xFFF3F0F8)),
                          itemBuilder: (context, i) {
                            if (i == 0) {
                              return const Text(
                                'Your previous bookings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: LooksUi.ink,
                                ),
                              );
                            }
                            final a = _items[i - 1];
                            final photo = _photo(a, auth);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: 72,
                                      height: 72,
                                      child: LookPhoto(
                                        url: photo.isEmpty ? null : photo,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.shopName ?? 'Salon',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            color: LooksUi.ink,
                                          ),
                                        ),
                                        Text(
                                          a.serviceName ?? 'Appointment',
                                          style: const TextStyle(
                                            color: LooksUi.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if ((a.barberName ?? '').trim().isNotEmpty)
                                          Text(
                                            'With ${a.barberName}',
                                            style: const TextStyle(
                                              color: LooksUi.muted,
                                              fontSize: 13,
                                            ),
                                          ),
                                        Text(
                                          _dateLabel(a.scheduledStart),
                                          style: const TextStyle(
                                            color: LooksUi.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (a.shopId != null && a.shopId!.isNotEmpty)
                                        SaveShopHeart(
                                          shopId: a.shopId!,
                                          barberUserId: a.barberUserId,
                                        ),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed: () => _book(a),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: LooksUi.purple,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(0, 36),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Book again',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
