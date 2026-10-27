import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/open_link.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import 'looks_ui.dart';

enum _ApptStatus { upcoming, completed, cancelled }

class _ApptItem {
  const _ApptItem({
    required this.apiId,
    required this.start,
    required this.salon,
    required this.status,
    required this.paymentStatus,
    required this.price,
    required this.dto,
    this.paymentMethod,
    this.address,
    this.service,
    this.stylist,
    this.reviewed = false,
  });

  final String apiId;
  final DateTime start;
  final String salon;
  final _ApptStatus status;
  final String paymentStatus;
  final double price;
  final String? paymentMethod;
  final String? address;
  final String? service;
  final String? stylist;
  final AppointmentDto dto;
  final bool reviewed;

  factory _ApptItem.fromDto(
    AppointmentDto a, {
    required bool upcoming,
    required bool reviewed,
  }) {
    final status = upcoming
        ? _ApptStatus.upcoming
        : a.isCancelled
            ? _ApptStatus.cancelled
            : _ApptStatus.completed;
    return _ApptItem(
      apiId: a.id,
      start: a.scheduledStart.toLocal(),
      salon: a.shopName ?? 'Salon',
      address: a.shopAddress,
      service: a.serviceName,
      stylist: a.barberName,
      status: status,
      paymentStatus: a.paymentStatus,
      paymentMethod: a.paymentMethod,
      price: a.priceSnapshot,
      dto: a,
      reviewed: reviewed,
    );
  }
}

/// Looksy "My Bookings" — Upcoming / Past.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => AppointmentsScreenState();
}

class AppointmentsScreenState extends State<AppointmentsScreen> {
  var _loading = true;
  String? _error;
  var _tab = 0;
  List<_ApptItem> _upcoming = const [];
  List<_ApptItem> _past = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<AuthController>().appointmentsApi;
    try {
      final opened = await api.list(status: 'OPENED');
      final closed = await api.list(status: 'CLOSED');
      final reviews = await SessionStore().readReviews();
      final reviewedIds = reviews.map((r) => r['appointmentId'] as String?).toSet();
      if (!mounted) return;
      setState(() {
        _upcoming = opened
            .map((a) => _ApptItem.fromDto(a, upcoming: true, reviewed: false))
            .toList();
        _past = closed
            .map(
              (a) => _ApptItem.fromDto(
                a,
                upcoming: false,
                reviewed: reviewedIds.contains(a.id),
              ),
            )
            .toList();
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

  Future<void> _openDetails(_ApptItem item) async {
    final changed = await showAppointmentDetailsSheet(
      context,
      appointment: item.dto,
    );
    if (changed && mounted) await _load();
  }

  Future<void> _cancel(_ApptItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => const _CancelDialog(),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AuthController>().appointmentsApi.updateStatus(
        id: item.apiId,
        status: 'CANCELLED',
      );
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _leaveReview(_ApptItem item) async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.leaveReview,
      arguments: LeaveReviewArgs(
        appointmentId: item.apiId,
        salonName: item.salon,
        serviceName: item.service ?? 'Appointment',
        dateLabel: '${_prettyDate(item.start)} · ${_prettyTime(item.start)}',
        imageUrl: item.dto.shopImageUrl.isNotEmpty
            ? item.dto.shopImageUrl
            : item.dto.barberAvatar,
      ),
    );
    if (result == true && mounted) await _load();
  }

  void _bookAgain(_ApptItem item) {
    final shopId = item.dto.shopId;
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
        salonName: item.salon,
        address: item.address ?? '',
        imageUrl: item.dto.shopImageUrl.isNotEmpty
            ? item.dto.shopImageUrl
            : item.dto.barberAvatar,
        barberUserId: item.dto.barberUserId,
        lookName: item.service,
        serviceId: item.dto.serviceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: _loading
            ? const AppointmentsSkeleton()
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Text(
                          'My Bookings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: LooksUi.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: LooksUi.searchFill,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              _SegmentTab(
                                label: 'Upcoming',
                                selected: _tab == 0,
                                onTap: () => setState(() => _tab = 0),
                              ),
                              _SegmentTab(
                                label: 'Past',
                                selected: _tab == 1,
                                onTap: () => setState(() => _tab = 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: RefreshIndicator(
                          color: LooksUi.purple,
                          onRefresh: _load,
                          child: _tab == 0
                              ? _BookingList(
                                  items: _upcoming,
                                  emptyTitle: 'No upcoming bookings',
                                  emptySubtitle: 'Find a look and book instantly.',
                                  itemBuilder: (context, i) => _UpcomingCard(
                                    item: _upcoming[i],
                                    onReschedule: () =>
                                        _openDetails(_upcoming[i]),
                                    onCancel: () => _cancel(_upcoming[i]),
                                  ),
                                )
                              : _BookingList(
                                  items: _past,
                                  emptyTitle: 'No past bookings',
                                  emptySubtitle:
                                      'Completed and cancelled bookings appear here.',
                                  itemBuilder: (context, i) => _PastCard(
                                    item: _past[i],
                                    onReview: _past[i].status ==
                                                _ApptStatus.completed &&
                                            !_past[i].reviewed
                                        ? () => _leaveReview(_past[i])
                                        : null,
                                    onBookAgain: _past[i].status ==
                                            _ApptStatus.completed
                                        ? () => _bookAgain(_past[i])
                                        : null,
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

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
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
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: selected ? Colors.white : LooksUi.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  const _BookingList({
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.itemBuilder,
  });

  final List<_ApptItem> items;
  final String emptyTitle;
  final String emptySubtitle;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        children: [
          Icon(Icons.event_available_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: LooksUi.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            emptySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: LooksUi.muted),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: itemBuilder,
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.item,
    required this.onReschedule,
    required this.onCancel,
  });

  final _ApptItem item;
  final VoidCallback onReschedule;
  final VoidCallback onCancel;

  Future<void> _maps() async {
    final q = Uri.encodeComponent(item.address ?? item.salon);
    await openExternalUri(Uri.parse('https://maps.google.com/?q=$q'));
  }

  Future<void> _calendar() async {
    final title = Uri.encodeComponent('${item.service ?? 'STYL'} · ${item.salon}');
    final start = item.start
        .toUtc()
        .toIso8601String()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .split('.')
        .first;
    await openExternalUri(
      Uri.parse(
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$start/$start',
      ),
    );
  }

  Future<void> _message(BuildContext context) async {
    final phone = item.dto.shopPhone ?? item.dto.barberPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number listed for this salon.')),
      );
      return;
    }
    await openExternalUri(Uri.parse('sms:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFECEAF3)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: _BookingHeader(item: item),
              ),
              const Divider(height: 1, color: Color(0xFFECEAF3)),
              _ActionRow(
                icon: Icons.calendar_today_outlined,
                label: 'Add to calendar',
                onTap: _calendar,
              ),
              const Divider(height: 1, indent: 52, color: Color(0xFFECEAF3)),
              _ActionRow(
                icon: Icons.near_me_outlined,
                label: 'Get directions',
                onTap: _maps,
              ),
              const Divider(height: 1, indent: 52, color: Color(0xFFECEAF3)),
              _ActionRow(
                icon: Icons.schedule_outlined,
                label: 'Reschedule',
                onTap: onReschedule,
              ),
              const Divider(height: 1, indent: 52, color: Color(0xFFECEAF3)),
              _ActionRow(
                icon: Icons.event_busy_outlined,
                label: 'Cancel booking',
                onTap: onCancel,
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 22, 4, 10),
          child: Text(
            'Need help?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: LooksUi.ink,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFECEAF3)),
          ),
          child: InkWell(
            onTap: () => _message(context),
            borderRadius: BorderRadius.circular(16),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, color: LooksUi.ink, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Message business',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: LooksUi.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: LooksUi.muted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PastCard extends StatelessWidget {
  const _PastCard({
    required this.item,
    this.onReview,
    this.onBookAgain,
  });

  final _ApptItem item;
  final VoidCallback? onReview;
  final VoidCallback? onBookAgain;

  @override
  Widget build(BuildContext context) {
    final cancelled = item.status == _ApptStatus.cancelled;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFECEAF3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BookingHeader(item: item),
                if (cancelled)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Cancelled',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onReview != null) ...[
            const Divider(height: 1, color: Color(0xFFECEAF3)),
            _ActionRow(
              icon: Icons.star_outline_rounded,
              label: 'Leave a review',
              onTap: onReview!,
            ),
          ],
          if (onBookAgain != null) ...[
            const Divider(height: 1, color: Color(0xFFECEAF3)),
            _ActionRow(
              icon: Icons.replay_rounded,
              label: 'Book again',
              onTap: onBookAgain!,
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader({required this.item});

  final _ApptItem item;

  String get _place {
    final area = (item.dto.shopArea ?? '').trim();
    if (area.isNotEmpty) return area;
    final address = (item.address ?? '').split(',').first.trim();
    return address.isEmpty ? 'Nearby' : address;
  }

  @override
  Widget build(BuildContext context) {
    final image = item.dto.shopImageUrl.isNotEmpty
        ? item.dto.shopImageUrl
        : (item.dto.barberAvatar ?? '');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: image.isNotEmpty
                ? Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallback(),
                  )
                : _fallback(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.salon,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: LooksUi.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.service ?? 'Appointment',
                style: const TextStyle(color: LooksUi.muted, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '${_prettyDate(item.start)} · ${_prettyTime(item.start)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: LooksUi.ink,
                ),
              ),
              Text(
                _place,
                style: const TextStyle(color: LooksUi.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    return ColoredBox(
      color: LooksUi.searchFill,
      child: Center(
        child: Text(
          item.salon.isEmpty ? '?' : item.salon[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: LooksUi.ink),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: LooksUi.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _prettyDate(DateTime start) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(start.year, start.month, start.day);
  if (day == today) return 'Today, ${start.day} ${months[start.month - 1]}';
  return '${start.day} ${months[start.month - 1]}';
}

String _prettyTime(DateTime start) {
  final h = start.hour;
  final m = start.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $ampm';
}

class _CancelDialog extends StatelessWidget {
  const _CancelDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cancel this booking?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This can’t be undone. The salon will be notified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: LooksUi.purple,
                    ),
                    child: const Text('Cancel booking'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
