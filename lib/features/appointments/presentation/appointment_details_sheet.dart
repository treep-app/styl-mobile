import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/notifications/notification_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../../widgets/styl_primary_button.dart';

/// Opens the full appointment details sheet. Returns true if the booking
/// was changed (status, schedule) so lists can reload.
Future<bool> showAppointmentDetailsSheet(
  BuildContext context, {
  required AppointmentDto appointment,
}) async {
  var changed = false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AppointmentDetailsSheet(
      initial: appointment,
      onChanged: () => changed = true,
    ),
  );
  return result == true || changed;
}

class AppointmentDetailsSheet extends StatefulWidget {
  const AppointmentDetailsSheet({
    super.key,
    required this.initial,
    this.onChanged,
  });

  final AppointmentDto initial;
  final VoidCallback? onChanged;

  @override
  State<AppointmentDetailsSheet> createState() =>
      _AppointmentDetailsSheetState();
}

class _AppointmentDetailsSheetState extends State<AppointmentDetailsSheet> {
  late AppointmentDto _appointment = widget.initial;
  var _loading = true;
  var _acting = false;
  var _rescheduleOpen = false;
  DateTime _rescheduleDay = DateTime.now();
  List<SlotDto> _slots = const [];
  var _slotsLoading = false;
  String? _slotsError;
  SlotDto? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final start = widget.initial.scheduledStart.toLocal();
    _rescheduleDay = DateTime(start.year, start.month, start.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  AuthController get _auth => context.read<AuthController>();

  bool get _isClient {
    final id = _auth.user?.id;
    return id != null && id == _appointment.clientUserId;
  }

  bool get _isAssignedBarber {
    final id = _auth.user?.id;
    return id != null && id == _appointment.barberUserId;
  }

  bool get _isShopOwner {
    final id = _auth.user?.id;
    return id != null && id == _appointment.shopOwnerUserId;
  }

  bool get _isProvider => _auth.user?.isBarber == true;

  bool get _canManage => _isClient || _isAssignedBarber || _isShopOwner;

  void _markChanged() => widget.onChanged?.call();

  Future<void> _refresh() async {
    try {
      final fresh = await _auth.appointmentsApi.getById(_appointment.id);
      if (!mounted) return;
      setState(() {
        _appointment = fresh;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _close() => Navigator.of(context).pop();

  Future<void> _showError(Object error) async {
    if (!mounted) return;
    final message = error is ApiException
        ? error.message
        : friendlyErrorMessage(error);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: destructive
                              ? AppColors.error
                              : AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return ok == true;
  }

  Future<void> _setStatus(String status) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final updated = await _auth.appointmentsApi.updateStatus(
        id: _appointment.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _appointment = updated;
        _acting = false;
        _rescheduleOpen = false;
      });
      _markChanged();
      // Push the new alert to the other party's inbox badge promptly.
      context.read<NotificationController>().refresh(silent: true);
      if (mounted) {
        final message = switch (status) {
          'CONFIRMED' => 'Booking confirmed — customer notified.',
          'CANCELLED' => 'Booking cancelled — other party notified.',
          'COMPLETED' => 'Appointment marked completed.',
          _ => 'Appointment updated.',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      await _showError(e);
    }
  }

  Future<void> _cancel() async {
    final ok = await _confirm(
      title: 'Cancel this appointment?',
      body: _isProvider
          ? 'The client will be notified. This can’t be undone.'
          : 'The salon will be notified. This can’t be undone.',
      confirmLabel: 'Cancel',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _setStatus('CANCELLED');
  }

  Future<void> _complete() async {
    final ok = await _confirm(
      title: 'Mark as completed?',
      body:
          'This will close the appointment for ${_appointment.clientName ?? 'the client'}.',
      confirmLabel: 'Complete',
    );
    if (!ok || !mounted) return;
    await _setStatus('COMPLETED');
  }

  Future<void> _confirmBooking() async {
    await _setStatus('CONFIRMED');
  }

  Future<void> _call(String? phone, {required String emptyLabel}) async {
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emptyLabel)));
      return;
    }
    final uri = Uri(scheme: 'tel', path: trimmed);
    final launched = await launchUrl(uri);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone app.')),
      );
    }
  }

  Future<void> _loadSlots(DateTime day) async {
    final barberId = _appointment.barberUserId;
    if (barberId == null) return;
    setState(() {
      _rescheduleDay = DateTime(day.year, day.month, day.day);
      _slotsLoading = true;
      _slotsError = null;
      _selectedSlot = null;
    });
    final key =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    try {
      final slots = await _auth.catalogApi.listSlots(
        barberId: barberId,
        date: key,
      );
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _slotsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _slotsLoading = false;
        _slotsError = e is ApiException ? e.message : friendlyErrorMessage(e);
      });
    }
  }

  bool _isCurrentSlot(SlotDto slot) {
    final slotTime = DateTime.parse(slot.startAt).toLocal();
    final current = _appointment.scheduledStart.toLocal();
    return slotTime.year == current.year &&
        slotTime.month == current.month &&
        slotTime.day == current.day &&
        slotTime.hour == current.hour &&
        slotTime.minute == current.minute;
  }

  Future<void> _openReschedule() async {
    setState(() => _rescheduleOpen = true);
    await _loadSlots(_rescheduleDay);
  }

  Future<void> _submitReschedule() async {
    final slot = _selectedSlot;
    if (slot == null || _acting) return;
    setState(() => _acting = true);
    try {
      final start = DateTime.parse(slot.startAt).toUtc().toIso8601String();
      final updated = await _auth.appointmentsApi.reschedule(
        id: _appointment.id,
        scheduledStart: start,
      );
      if (!mounted) return;
      setState(() {
        _appointment = updated;
        _acting = false;
        _rescheduleOpen = false;
        _selectedSlot = null;
      });
      _markChanged();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment rescheduled.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      await _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Appointment details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    _StatusChip(appointment: _appointment),
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.brandAccent,
                ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    _ServiceCard(appointment: _appointment),
                    const SizedBox(height: 12),
                    _BarberCard(appointment: _appointment),
                    const SizedBox(height: 12),
                    _PeopleScheduleCard(
                      appointment: _appointment,
                      isProvider: _isProvider,
                    ),
                    const SizedBox(height: 12),
                    _PaymentCard(appointment: _appointment),
                    if (_appointment.notes != null &&
                        _appointment.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _NotesCard(notes: _appointment.notes!.trim()),
                    ],
                    if (_rescheduleOpen) ...[
                      const SizedBox(height: 16),
                      _ReschedulePanel(
                        day: _rescheduleDay,
                        slots: _slots,
                        loading: _slotsLoading,
                        error: _slotsError,
                        selected: _selectedSlot,
                        isCurrentSlot: _isCurrentSlot,
                        onSelectDay: _loadSlots,
                        onSelectSlot: (slot) =>
                            setState(() => _selectedSlot = slot),
                      ),
                    ],
                  ],
                ),
              ),
              if (_appointment.isOpen || _isProvider || _isClient)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: _rescheduleOpen
                        ? Column(
                            children: [
                              StylPrimaryButton(
                                label: 'Save new time',
                                isLoading: _acting,
                                onPressed: _selectedSlot == null
                                    ? null
                                    : _submitReschedule,
                              ),
                              TextButton(
                                onPressed: _acting
                                    ? null
                                    : () => setState(
                                        () => _rescheduleOpen = false,
                                      ),
                                child: const Text('Back to details'),
                              ),
                            ],
                          )
                        : _Actions(
                            acting: _acting,
                            isProvider: _isProvider,
                            onReschedule: _appointment.isOpen && _canManage
                                ? _openReschedule
                                : null,
                            onCancel: _appointment.isOpen && _canManage
                                ? _cancel
                                : null,
                            onComplete:
                                (_isAssignedBarber || _isShopOwner) &&
                                    _appointment.isConfirmed
                                ? _complete
                                : null,
                            onConfirm:
                                (_isAssignedBarber || _isShopOwner) &&
                                    _appointment.isPending
                                ? _confirmBooking
                                : null,
                            onContact: _isProvider
                                ? () => _call(
                                    _appointment.clientPhone,
                                    emptyLabel:
                                        'No client phone number on file.',
                                  )
                                : () => _call(
                                    _appointment.barberPhone ??
                                        _appointment.shopPhone,
                                    emptyLabel:
                                        'No barber or salon phone number on file.',
                                  ),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.appointment});

  final AppointmentDto appointment;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (appointment.isCancelled) {
      bg = const Color(0xFFFFEBEE);
      fg = AppColors.error;
    } else if (appointment.isCompleted) {
      bg = const Color(0xFFE8F5E9);
      fg = AppColors.success;
    } else if (appointment.isPending) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
    } else {
      bg = const Color(0xFFE3F2FD);
      fg = AppColors.brandPrimary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        appointment.statusLabel,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightOutlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.appointment});

  final AppointmentDto appointment;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Service procured',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appointment.serviceName ?? 'Appointment',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.durationLabel,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add-ons',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
          ),
          const SizedBox(height: 2),
          const Text(
            'None',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  const _BarberCard({required this.appointment});

  final AppointmentDto appointment;

  @override
  Widget build(BuildContext context) {
    final online = appointment.barberIsOnline;
    return _SectionCard(
      title: 'Assigned barber',
      child: Row(
        children: [
          PresenceAvatar(
            size: 52,
            imageUrl: appointment.barberAvatar,
            name: appointment.barberName,
            isOnline: online,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.barberName ?? 'Barber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  appointment.barberStatusLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: online
                        ? PresenceAvatar.onlineGreen
                        : const Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeopleScheduleCard extends StatelessWidget {
  const _PeopleScheduleCard({
    required this.appointment,
    required this.isProvider,
  });

  final AppointmentDto appointment;
  final bool isProvider;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: isProvider ? 'Client & schedule' : 'Your booking',
      child: Column(
        children: [
          if (isProvider)
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Client',
              value: appointment.clientName ?? 'Client',
            ),
          if (isProvider)
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Contact',
              value: appointment.clientPhone?.trim().isNotEmpty == true
                  ? appointment.clientPhone!
                  : 'Not provided',
            ),
          if (!isProvider)
            _InfoRow(
              icon: Icons.storefront_outlined,
              label: 'Salon',
              value: appointment.shopName ?? 'Salon',
            ),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: appointment.dateLabel,
          ),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'Time',
            value: appointment.timeRangeLabel,
          ),
          if (appointment.shopAddress != null &&
              appointment.shopAddress!.trim().isNotEmpty)
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: appointment.shopAddress!,
            ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.appointment});

  final AppointmentDto appointment;

  @override
  Widget build(BuildContext context) {
    final paid = appointment.isPaid;
    return _SectionCard(
      title: 'Price & payment',
      child: Column(
        children: [
          _PriceRow(
            label: appointment.serviceName ?? 'Service',
            value: appointment.servicePriceLabel,
          ),
          _PriceRow(
            label: 'STYL booking fee',
            value: appointment.hasBookingFee
                ? appointment.bookingFeeLabel
                : '—',
          ),
          const _PriceRow(label: 'Add-ons', value: 'None'),
          const _PriceRow(label: 'Discount / promo', value: 'None'),
          const _PriceRow(label: 'Tax', value: '—'),
          const Divider(height: 20),
          _PriceRow(
            label: 'Total',
            value: appointment.totalLabel,
            emphasize: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: paid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                appointment.paymentStatusLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: paid
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFE65100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Notes',
      child: Text(notes, style: const TextStyle(fontSize: 14, height: 1.4)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: emphasize ? 16 : 14,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      color: emphasize ? AppColors.brandPrimary : const Color(0xFF111827),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ReschedulePanel extends StatelessWidget {
  const _ReschedulePanel({
    required this.day,
    required this.slots,
    required this.loading,
    required this.error,
    required this.selected,
    required this.isCurrentSlot,
    required this.onSelectDay,
    required this.onSelectSlot,
  });

  final DateTime day;
  final List<SlotDto> slots;
  final bool loading;
  final String? error;
  final SlotDto? selected;
  final bool Function(SlotDto slot) isCurrentSlot;
  final ValueChanged<DateTime> onSelectDay;
  final ValueChanged<SlotDto> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final days = List.generate(7, (i) => todayDate.add(Duration(days: i)));

    return _SectionCard(
      title: 'Reschedule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final d = days[index];
                final isSelected =
                    d.year == day.year &&
                    d.month == day.month &&
                    d.day == day.day;
                const labels = [
                  'Mon',
                  'Tue',
                  'Wed',
                  'Thu',
                  'Fri',
                  'Sat',
                  'Sun',
                ];
                return GestureDetector(
                  onTap: () => onSelectDay(d),
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandAccent
                          : AppColors.lightSurfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          labels[d.weekday - 1],
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white70
                                : const Color(0xFF8A8A8A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (error != null)
            Text(error!, style: const TextStyle(color: AppColors.error))
          else if (slots.isEmpty)
            const Text('No slots on this day.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in slots)
                  _SlotChip(
                    slot: slot,
                    selected: selected?.startAt == slot.startAt,
                    available: slot.available || isCurrentSlot(slot),
                    onTap: () => onSelectSlot(slot),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final SlotDto slot;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: available ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandAccent
              : available
              ? Colors.white
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.brandAccent
                : AppColors.lightOutlineVariant,
          ),
        ),
        child: Text(
          slot.start,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : available
                ? const Color(0xFF111827)
                : const Color(0xFFBDBDBD),
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.acting,
    required this.isProvider,
    required this.onContact,
    this.onReschedule,
    this.onCancel,
    this.onComplete,
    this.onConfirm,
  });

  final bool acting;
  final bool isProvider;
  final VoidCallback onContact;
  final VoidCallback? onReschedule;
  final VoidCallback? onCancel;
  final VoidCallback? onComplete;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onConfirm != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StylPrimaryButton(
              label: 'Confirm appointment',
              isLoading: acting,
              onPressed: acting ? null : onConfirm,
            ),
          ),
        if (onComplete != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: StylPrimaryButton(
              label: 'Mark as completed',
              isLoading: acting,
              onPressed: acting ? null : onComplete,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: acting ? null : onContact,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandPrimary),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: Text(isProvider ? 'Contact client' : 'Contact barber'),
              ),
            ),
            if (onReschedule != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: acting ? null : onReschedule,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandAccent,
                    side: const BorderSide(color: AppColors.brandAccent),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text('Reschedule'),
                ),
              ),
            ],
          ],
        ),
        if (onCancel != null)
          TextButton(
            onPressed: acting ? null : onCancel,
            child: const Text(
              'Cancel appointment',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
