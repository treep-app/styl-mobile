import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/payments/booking_fee.dart';
import '../../../core/payments/stripe_payments.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';
import 'customer_shell_tabs.dart';
import 'looks_ui.dart';

enum _PayKind { wallet, card, cash }

enum _TimePeriod { morning, afternoon, evening }

/// Looksy booking: service + date/time → review & pay → confirmation.
class LooksBookScreen extends StatefulWidget {
  const LooksBookScreen({super.key, required this.args});

  final LooksBookArgs args;

  @override
  State<LooksBookScreen> createState() => _LooksBookScreenState();
}

class _LooksBookScreenState extends State<LooksBookScreen> {
  var _step = 0;
  var _loading = true;
  String? _error;
  List<ServiceDto> _services = const [];
  ServiceDto? _service;
  late DateTime _selectedDate;
  List<DateTime> _days = const [];
  List<SlotDto> _slots = const [];
  SlotDto? _slot;
  var _loadingSlots = false;
  String? _barberId;
  var _payKind =
      StripePayments.walletEnabled ? _PayKind.wallet : _PayKind.card;
  String? _selectedCardId;
  List<PaymentMethodDto> _cards = const [];
  var _submitting = false;
  String? _busyMessage;
  String? _pendingAppointmentId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pref = widget.args.preferredDate;
    _selectedDate = pref == null
        ? today
        : DateTime(pref.year, pref.month, pref.day);
    _days = List.generate(7, (i) => today.add(Duration(days: i)));
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthController>();
    try {
      final shop = await auth.catalogApi.getShop(widget.args.shopId);
      final services = shop.services.isNotEmpty
          ? shop.services
          : await auth.catalogApi.listServices(widget.args.shopId);
      final specialists = await auth.catalogApi.listSpecialists(widget.args.shopId);
      var barberId = widget.args.barberUserId ?? shop.ownerUserId;
      if (specialists.isNotEmpty) {
        final preferred = widget.args.barberUserId;
        final match = specialists.indexWhere((s) => s.id == preferred);
        barberId = match >= 0 ? specialists[match].id : specialists.first.id;
      }
      ServiceDto? service;
      final wantedId = widget.args.serviceId;
      if (wantedId != null) {
        for (final s in services) {
          if (s.id == wantedId) {
            service = s;
            break;
          }
        }
      }
      service ??= _matchService(services, widget.args.lookName);

      List<PaymentMethodDto> cards = const [];
      try {
        cards = await auth.paymentsApi.listMethods();
      } catch (_) {}

      PaymentMethodDto? saved;
      for (final c in cards) {
        if (c.isDefault) {
          saved = c;
          break;
        }
      }
      saved ??= cards.isEmpty ? null : cards.first;
      if (!mounted) return;
      setState(() {
        _services = services;
        _service = service;
        _barberId = barberId;
        _cards = cards;
        _selectedCardId = saved?.id;
        _loading = false;
      });
      await _loadSlots();
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

  ServiceDto? _matchService(List<ServiceDto> services, String? lookName) {
    if (services.isEmpty) return null;
    final hay = (lookName ?? '').toLowerCase();
    if (hay.isEmpty) return services.first;
    for (final s in services) {
      final n = s.name.toLowerCase();
      if (hay.contains(n) || n.contains(hay.split(' ').first)) return s;
    }
    return services.first;
  }

  String get _dateQuery {
    final d = _selectedDate;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _loadSlots() async {
    final barberId = _barberId;
    if (barberId == null || barberId.isEmpty) {
      setState(() => _slots = const []);
      return;
    }
    setState(() {
      _loadingSlots = true;
      _slot = null;
    });
    try {
      final slots = await context.read<AuthController>().catalogApi.listSlots(
            barberId: barberId,
            date: _dateQuery,
          );
      if (!mounted) return;
      final available = slots.where((s) => s.available).toList();
      SlotDto? picked = _slot;
      final want = widget.args.preferredSlotStartAt;
      if (want != null) {
        for (final s in available) {
          if (s.startAt == want) {
            picked = s;
            break;
          }
        }
      }
      setState(() {
        _slots = available;
        _loadingSlots = false;
        _slot = picked;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slots = const [];
        _loadingSlots = false;
      });
    }
  }

  void _goBack() {
    if (_step == 0 || _step == 2) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
  }

  void _continueFromBook() {
    if (_service == null && _services.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a service.')),
      );
      return;
    }
    if (_slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a time.')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  ({String method, String? paymentMethodId}) get _resolvedPayment {
    if (_payKind == _PayKind.cash) {
      return (method: 'CASH', paymentMethodId: null);
    }
    final cardId = _selectedCardId;
    if (_payKind == _PayKind.card &&
        cardId != null &&
        cardId.startsWith('pm_')) {
      return (method: 'CARD', paymentMethodId: cardId);
    }
    return (method: 'WALLET', paymentMethodId: null);
  }

  double get _serviceAmount => _service?.priceAmount ?? 0;

  double get _bookingFee => computeStylBookingFee();

  String get _bookingFeeLabel => stylFeeLabel(_bookingFee);

  bool get _payAtSalon => _payKind == _PayKind.cash;

  double get _dueNow => stylAmountDueNow(
        payAtSalon: _payAtSalon,
        serviceAmount: _serviceAmount,
      );

  String get _dueNowLabel => stylFeeLabel(_dueNow);

  String get _dateLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = _selectedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final prefix = DateTime(d.year, d.month, d.day) == today ? 'Today, ' : '';
    return '$prefix${d.day} ${months[d.month - 1]}';
  }

  String get _timeLabel => _slot == null ? '—' : _formatTime(_slot!.start);

  String get _durationLabel {
    final mins = _service?.durationMin ?? 45;
    return '$mins mins';
  }

  String get _priceLabel => _service?.priceLabel ?? 'From £25';

  Future<void> _confirmBooking() async {
    final barberId = _barberId;
    final slot = _slot;
    if (barberId == null || slot == null) return;

    setState(() {
      _submitting = true;
      _busyMessage = 'Creating your booking…';
    });

    final auth = context.read<AuthController>();
    final resolved = _resolvedPayment;
    final payMethod = resolved.method;
    final paymentMethodId = resolved.paymentMethodId;

    void clearBusy() {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _busyMessage = null;
      });
    }

    try {
      late AppointmentDto created;
      final existingId = _pendingAppointmentId;
      if (existingId != null) {
        created = await auth.appointmentsApi.getById(existingId);
        if (created.paymentStatus == 'PAID') {
          if (!mounted) return;
          setState(() {
            _step = 2;
            _submitting = false;
            _busyMessage = null;
          });
          return;
        }
      } else {
        created = await auth.appointmentsApi.create(
          shopId: widget.args.shopId,
          barberUserId: barberId,
          scheduledStart: slot.startAt,
          serviceId: _service?.id,
          paymentMethod: payMethod,
          notes: widget.args.lookName == null
              ? null
              : 'Look: ${widget.args.lookName}',
        );
        _pendingAppointmentId = created.id;
      }
      if (!mounted) return;

      setState(() => _busyMessage = 'Taking payment…');
      final paid = await auth.appointmentsApi.pay(
        id: created.id,
        paymentMethod: payMethod,
        paymentMethodId: paymentMethodId,
      );
      if (!mounted) return;

      if (paid.appointment.paymentStatus == 'PAID') {
        setState(() {
          _step = 2;
          _submitting = false;
          _busyMessage = null;
        });
        return;
      }

      if (paid.checkout.usesPaymentSheet) {
        final publishableKey = paid.checkout.publishableKey;
        final clientSecret = paid.checkout.clientSecret!;
        final paymentIntentId = paid.checkout.providerRef;
        if (publishableKey == null ||
            publishableKey.isEmpty ||
            paymentIntentId == null ||
            paymentIntentId.isEmpty) {
          clearBusy();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stripe is misconfigured on the server.')),
          );
          return;
        }
        await StripePayments.configure(publishableKey: publishableKey);
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _busyMessage = null;
        });
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        final completed = await StripePayments.presentPaymentSheet(
          clientSecret: clientSecret,
        );
        if (!mounted) return;
        if (!completed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment cancelled. Pay the STYL booking fee to finish this booking.',
              ),
            ),
          );
          return;
        }
        setState(() {
          _submitting = true;
          _busyMessage = 'Confirming payment…';
        });
        await auth.appointmentsApi.confirmPayment(
          id: paid.appointment.id,
          paymentIntentId: paymentIntentId,
        );
        if (!mounted) return;
        final verified = await auth.appointmentsApi.getById(paid.appointment.id);
        if (!mounted) return;
        if (verified.paymentStatus != 'PAID') {
          clearBusy();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Booking fee is not paid yet. Complete payment to confirm.',
              ),
            ),
          );
          return;
        }
        setState(() {
          _step = 2;
          _submitting = false;
          _busyMessage = null;
        });
        return;
      }

      if (paid.checkout.requiresAction &&
          (paid.checkout.checkoutUrl ?? '').isNotEmpty) {
        await launchUrl(
          Uri.parse(paid.checkout.checkoutUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        clearBusy();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Finish paying the STYL booking fee to confirm this booking.',
            ),
          ),
        );
        return;
      }
      clearBusy();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pay the STYL booking fee to confirm this booking.',
          ),
        ),
      );
    } catch (e) {
      clearBusy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  void _viewBooking() {
    CustomerShellTabs.goTo(CustomerShellTabs.appointments);
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == AppRoutes.customerShell || route.isFirst,
    );
  }

  Future<void> _openMaps() async {
    final q = Uri.encodeComponent(widget.args.address);
    await launchUrl(
      Uri.parse('https://maps.google.com/?q=$q'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _addToCalendar() async {
    final start = _slot?.startAt ?? DateTime.now().toUtc().toIso8601String();
    final title = Uri.encodeComponent(
      '${widget.args.lookName ?? _service?.name ?? 'STYL'} · ${widget.args.salonName}',
    );
    final dates = start.replaceAll('-', '').replaceAll(':', '').split('.').first;
    await launchUrl(
      Uri.parse(
        'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$dates/$dates',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Book Appointment',
      1 => 'Review & Confirm',
      _ => 'Booking Confirmed',
    };

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _step == 2
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              foregroundColor: LooksUi.ink,
              elevation: 0,
              leading: IconButton(
                onPressed: _goBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: LooksUi.ink,
                ),
              ),
              centerTitle: true,
            ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _bootstrap, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else
            switch (_step) {
              0 => _BookStep(
                  args: widget.args,
                  services: _services,
                  selected: _service,
                  days: _days,
                  selectedDate: _selectedDate,
                  slots: _slots,
                  loadingSlots: _loadingSlots,
                  selectedSlot: _slot,
                  onSelectService: (s) => setState(() => _service = s),
                  onSelectDate: (d) {
                    setState(() => _selectedDate = d);
                    _loadSlots();
                  },
                  onSelectSlot: (s) => setState(() => _slot = s),
                  onContinue: _continueFromBook,
                ),
              1 => _ConfirmStep(
                  args: widget.args,
                  service: _service,
                  dateLabel: _dateLabel,
                  timeLabel: _timeLabel,
                  durationLabel: _durationLabel,
                  priceLabel: _priceLabel,
                  feeLabel: _bookingFeeLabel,
                  dueNowLabel: _dueNowLabel,
                  payAtSalon: _payAtSalon,
                  payKind: _payKind,
                  cards: _cards,
                  selectedCardId: _selectedCardId,
                  onPayKind: (k) {
                    setState(() {
                      _payKind = k;
                      if (k == _PayKind.card && _selectedCardId == null && _cards.isNotEmpty) {
                        _selectedCardId = _cards.first.id;
                      }
                    });
                  },
                  onSelectCard: (id) => setState(() {
                    _payKind = _PayKind.card;
                    _selectedCardId = id;
                  }),
                  onAddCard: () async {
                    final auth = context.read<AuthController>();
                    final added = await Navigator.of(context)
                        .pushNamed(AppRoutes.addCard);
                    if (!mounted) return;
                    try {
                      final cards = await auth.paymentsApi.listMethods();
                      if (!mounted) return;
                      setState(() {
                        _cards = cards;
                        if (cards.isNotEmpty && added == true) {
                          _payKind = _PayKind.card;
                          _selectedCardId = cards.first.id;
                        }
                      });
                    } catch (_) {}
                  },
                  onConfirm: _submitting ? null : _confirmBooking,
                ),
              _ => _DoneStep(
                  args: widget.args,
                  service: _service,
                  dateLabel: _dateLabel,
                  timeLabel: _timeLabel,
                  durationLabel: _durationLabel,
                  priceLabel: _priceLabel,
                  feeLabel: _bookingFeeLabel,
                  payAtSalon: _payAtSalon,
                  onCalendar: _addToCalendar,
                  onDirections: _openMaps,
                  onView: _viewBooking,
                ),
            },
          if (_submitting)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    if (_busyMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _busyMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatTime(String start) {
  final parts = start.split(':');
  if (parts.length < 2) return start;
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1].padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $ampm';
}

class _BookStep extends StatefulWidget {
  const _BookStep({
    required this.args,
    required this.services,
    required this.selected,
    required this.days,
    required this.selectedDate,
    required this.slots,
    required this.loadingSlots,
    required this.selectedSlot,
    required this.onSelectService,
    required this.onSelectDate,
    required this.onSelectSlot,
    required this.onContinue,
  });

  final LooksBookArgs args;
  final List<ServiceDto> services;
  final ServiceDto? selected;
  final List<DateTime> days;
  final DateTime selectedDate;
  final List<SlotDto> slots;
  final bool loadingSlots;
  final SlotDto? selectedSlot;
  final ValueChanged<ServiceDto> onSelectService;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<SlotDto> onSelectSlot;
  final VoidCallback onContinue;

  @override
  State<_BookStep> createState() => _BookStepState();
}

class _BookStepState extends State<_BookStep> {
  _TimePeriod _period = _TimePeriod.morning;

  static int _hour(SlotDto s) =>
      int.tryParse(s.start.split(':').first) ?? 0;

  static _TimePeriod _periodFor(SlotDto s) {
    final h = _hour(s);
    if (h < 12) return _TimePeriod.morning;
    if (h < 17) return _TimePeriod.afternoon;
    return _TimePeriod.evening;
  }

  List<SlotDto> _slotsFor(_TimePeriod period) {
    return widget.slots.where((s) => _periodFor(s) == period).toList();
  }

  List<_TimePeriod> get _availablePeriods {
    return _TimePeriod.values
        .where((p) => _slotsFor(p).isNotEmpty)
        .toList();
  }

  List<SlotDto> get _visibleSlots => _slotsFor(_period);

  @override
  void initState() {
    super.initState();
    _syncPeriod();
  }

  @override
  void didUpdateWidget(covariant _BookStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slots != widget.slots ||
        oldWidget.selectedSlot?.startAt != widget.selectedSlot?.startAt) {
      _syncPeriod();
    }
  }

  void _syncPeriod() {
    final selected = widget.selectedSlot;
    if (selected != null) {
      _period = _periodFor(selected);
      return;
    }
    final available = _availablePeriods;
    if (available.isNotEmpty && !available.contains(_period)) {
      _period = available.first;
    }
  }

  Future<void> _pickService() async {
    if (widget.services.length <= 1) return;
    final picked = await showModalBottomSheet<ServiceDto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ServicePickerSheet(
        services: widget.services,
        selectedId: widget.selected?.id,
      ),
    );
    if (picked != null) widget.onSelectService(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final service = widget.selected;
    final periods = _availablePeriods;
    final visible = _visibleSlots;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Row(
            children: [
              StylAvatar(
                size: 48,
                imageUrl: widget.args.imageUrl,
                name: widget.args.salonName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.args.salonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    Text(
                      [
                        service?.name ?? widget.args.lookName ?? 'Service',
                        if (service != null)
                          '${service.priceLabel} · ${service.durationMin} mins',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.lightOnSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: _ServiceSelector(
            service: service,
            canChange: widget.services.length > 1,
            empty: widget.services.isEmpty,
            onTap: _pickService,
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select date',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        SizedBox(
          height: 68,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: widget.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final d = widget.days[i];
              final selectedDay = d.year == widget.selectedDate.year &&
                  d.month == widget.selectedDate.month &&
                  d.day == widget.selectedDate.day;
              return InkWell(
                onTap: () => widget.onSelectDate(d),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 68,
                  decoration: BoxDecoration(
                    color: selectedDay
                        ? AppColors.brandPrimary
                        : const Color(0xFFF3F7FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _chipTop(d),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedDay
                              ? Colors.white
                              : AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _chipBottom(d),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selectedDay
                              ? Colors.white
                              : AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select time',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
        if (!widget.loadingSlots && periods.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Row(
              children: [
                for (final p in periods) ...[
                  if (p != periods.first) const SizedBox(width: 8),
                  Expanded(
                    child: _PeriodChip(
                      label: switch (p) {
                        _TimePeriod.morning => 'Morning',
                        _TimePeriod.afternoon => 'Afternoon',
                        _TimePeriod.evening => 'Evening',
                      },
                      selected: _period == p,
                      onTap: () => setState(() => _period = p),
                    ),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: widget.loadingSlots
              ? const Center(child: CircularProgressIndicator())
              : widget.slots.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Text(
                        'No times left on this day. Try another date.',
                        style: TextStyle(color: AppColors.lightOnSurfaceVariant),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: 40,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final s = visible[i];
                        final on = widget.selectedSlot?.startAt == s.startAt;
                        return Material(
                          color: on
                              ? AppColors.brandPrimary
                              : const Color(0xFFF3F7FB),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => widget.onSelectSlot(s),
                            borderRadius: BorderRadius.circular(20),
                            child: Center(
                              child: Text(
                                _formatTime(s.start),
                                style: TextStyle(
                                  color: on
                                      ? Colors.white
                                      : AppColors.brandPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: widget.onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _chipTop(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    const w = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return w[d.weekday - 1];
  }

  static String _chipBottom(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${m[d.month - 1]}';
  }
}

class _ServiceSelector extends StatelessWidget {
  const _ServiceSelector({
    required this.service,
    required this.canChange,
    required this.empty,
    required this.onTap,
  });

  final ServiceDto? service;
  final bool canChange;
  final bool empty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (empty) {
      return const Text(
        'No listed services — we’ll book the look you chose.',
        style: TextStyle(color: AppColors.lightOnSurfaceVariant),
      );
    }
    return Material(
      color: const Color(0xFFF3F7FB),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: canChange ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canChange ? 'Service' : 'Selected service',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      service?.name ?? 'Choose a service',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (service != null)
                      Text(
                        '${service!.durationMin} mins',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                service?.priceLabel ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.brandPrimary,
                ),
              ),
              if (canChange) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.brandPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
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
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.brandPrimary : const Color(0xFFF3F7FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected ? Colors.white : AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}

class _ServicePickerSheet extends StatefulWidget {
  const _ServicePickerSheet({
    required this.services,
    required this.selectedId,
  });

  final List<ServiceDto> services;
  final String? selectedId;

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.services
        : widget.services
            .where((s) => s.name.toLowerCase().contains(q))
            .toList();
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    final showSearch = widget.services.length > 6;

    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E6ED),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a service',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
            ),
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search services',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF3F7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = list[i];
                  final on = s.id == widget.selectedId;
                  return ListTile(
                    onTap: () => Navigator.pop(context, s),
                    title: Text(
                      s.name,
                      style: TextStyle(
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('${s.durationMin} mins'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.priceLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (on) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.brandPrimary,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.args,
    required this.service,
    required this.dateLabel,
    required this.timeLabel,
    required this.durationLabel,
    required this.priceLabel,
    required this.feeLabel,
    required this.dueNowLabel,
    required this.payAtSalon,
    required this.payKind,
    required this.cards,
    required this.selectedCardId,
    required this.onPayKind,
    required this.onSelectCard,
    required this.onAddCard,
    required this.onConfirm,
  });

  final LooksBookArgs args;
  final ServiceDto? service;
  final String dateLabel;
  final String timeLabel;
  final String durationLabel;
  final String priceLabel;
  final String feeLabel;
  final String dueNowLabel;
  final bool payAtSalon;
  final _PayKind payKind;
  final List<PaymentMethodDto> cards;
  final String? selectedCardId;
  final ValueChanged<_PayKind> onPayKind;
  final ValueChanged<String> onSelectCard;
  final VoidCallback onAddCard;
  final VoidCallback? onConfirm;

  String get _placeLine {
    final area = args.address.split(',').first.trim();
    return [if (area.isNotEmpty) area, args.distance]
        .where((e) => e.isNotEmpty)
        .join(' · ');
  }

  bool get _cardSelected =>
      payKind == _PayKind.card || payKind == _PayKind.wallet;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: args.imageUrl != null &&
                              args.imageUrl!.trim().isNotEmpty
                          ? Image.network(
                              args.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: LooksUi.searchFill,
                                child: Center(
                                  child: Text(
                                    args.salonName.isEmpty
                                        ? '?'
                                        : args.salonName[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: LooksUi.ink,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: LooksUi.searchFill,
                              child: Center(
                                child: Text(
                                  args.salonName.isEmpty
                                      ? '?'
                                      : args.salonName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: LooksUi.ink,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.salonName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: LooksUi.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _placeLine,
                          style: const TextStyle(
                            color: LooksUi.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _kv(
                'Service',
                service?.name ?? args.lookName ?? 'Look',
                trailing: priceLabel,
              ),
              _kv('Date', dateLabel),
              _kv('Time', timeLabel),
              _kv('Duration', durationLabel),
              _kv('STYL fee', 'Platform fee', trailing: feeLabel),
              if (payAtSalon)
                _kv('At salon', 'Pay the professional', trailing: priceLabel)
              else
                _kv('Due now', 'Service + STYL fee', trailing: dueNowLabel),
              const SizedBox(height: 22),
              const Text(
                'Payment method',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: LooksUi.ink,
                ),
              ),
              const SizedBox(height: 12),
              for (final card in cards) ...[
                _PayMethodRow(
                  icon: Icons.credit_card_rounded,
                  label: '${card.brand} •••• ${card.last4}',
                  selected: payKind == _PayKind.card && selectedCardId == card.id,
                  onTap: () => onSelectCard(card.id),
                ),
                const SizedBox(height: 10),
              ],
              _PayMethodRow(
                icon: Icons.credit_card_rounded,
                label: cards.isEmpty ? 'Add card' : 'Add another card',
                selected: _cardSelected &&
                    (cards.isEmpty ||
                        selectedCardId == null ||
                        !cards.any((c) => c.id == selectedCardId)),
                onTap: () {
                  if (cards.isEmpty) {
                    onPayKind(_PayKind.card);
                  } else {
                    onAddCard();
                  }
                },
              ),
              const SizedBox(height: 10),
              _PayMethodRow(
                icon: Icons.storefront_outlined,
                label: 'Pay service at salon',
                selected: payKind == _PayKind.cash,
                onTap: () => onPayKind(_PayKind.cash),
              ),
              const SizedBox(height: 14),
              Text(
                payAtSalon
                    ? 'Pay $feeLabel now to confirm. You’ll pay $priceLabel to the professional at the salon.'
                    : 'Pay $dueNowLabel now (service + $feeLabel STYL fee). Nothing left at the salon.',
                style: const TextStyle(
                  color: LooksUi.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: LooksUi.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                'Pay $dueNowLabel to confirm',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              k,
              style: const TextStyle(color: LooksUi.muted, fontSize: 15),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: LooksUi.ink,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: LooksUi.ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _PayMethodRow extends StatelessWidget {
  const _PayMethodRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LooksUi.searchFill,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE6E3F0)),
                ),
                child: Icon(icon, size: 18, color: LooksUi.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: LooksUi.ink,
                  ),
                ),
              ),
              _RadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? LooksUi.purple : Colors.white,
        border: Border.all(
          color: selected ? LooksUi.purple : const Color(0xFFD0CDD8),
          width: 2,
        ),
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.args,
    required this.service,
    required this.dateLabel,
    required this.timeLabel,
    required this.durationLabel,
    required this.priceLabel,
    required this.feeLabel,
    required this.payAtSalon,
    required this.onCalendar,
    required this.onDirections,
    required this.onView,
  });

  final LooksBookArgs args;
  final ServiceDto? service;
  final String dateLabel;
  final String timeLabel;
  final String durationLabel;
  final String priceLabel;
  final String feeLabel;
  final bool payAtSalon;
  final VoidCallback onCalendar;
  final VoidCallback onDirections;
  final VoidCallback onView;

  String get _placeLine {
    final area = args.address.split(',').first.trim();
    return [if (area.isNotEmpty) area, args.distance]
        .where((e) => e.isNotEmpty)
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 12),
                  const _ConfirmedBadge(),
                  const SizedBox(height: 20),
                  const Text(
                    'Booking Confirmed!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: LooksUi.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    payAtSalon
                        ? 'You’re all set. STYL fee paid — pay the service at the salon.'
                        : 'You’re all set. Service and STYL fee are paid.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: LooksUi.muted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    decoration: BoxDecoration(
                      color: LooksUi.searchFill,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: args.imageUrl != null &&
                                        args.imageUrl!.trim().isNotEmpty
                                    ? Image.network(
                                        args.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _salonFallback(),
                                      )
                                    : _salonFallback(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    args.salonName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: LooksUi.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _placeLine,
                                    style: const TextStyle(
                                      color: LooksUi.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _row(
                          'Service',
                          service?.name ?? args.lookName ?? 'Look',
                          trailing: priceLabel,
                        ),
                        _row('STYL fee', 'Paid', trailing: feeLabel),
                        _row('Date', dateLabel),
                        _row('Time', timeLabel),
                        _row('Duration', durationLabel, last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _outlineAction(
                    icon: Icons.calendar_today_outlined,
                    label: 'Add to calendar',
                    onTap: onCalendar,
                  ),
                  const SizedBox(height: 10),
                  _outlineAction(
                    icon: Icons.near_me_outlined,
                    label: 'Get directions',
                    onTap: onDirections,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onView,
                style: FilledButton.styleFrom(
                  backgroundColor: LooksUi.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'View booking',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _salonFallback() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Text(
          args.salonName.isEmpty ? '?' : args.salonName[0].toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: LooksUi.ink,
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v, {String? trailing, bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              k,
              style: const TextStyle(color: LooksUi.muted, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: LooksUi.ink,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: LooksUi.ink,
              ),
            ),
        ],
      ),
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E3F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: LooksUi.ink),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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

class _ConfirmedBadge extends StatelessWidget {
  const _ConfirmedBadge();

  @override
  Widget build(BuildContext context) {
    const dots = <(double, double, Color, double)>[
      (-34, -18, Color(0xFFFFC84A), 7),
      (38, -16, Color(0xFF6B4EFF), 6),
      (-40, 28, Color(0xFF6B4EFF), 5),
      (42, 22, Color(0xFFFF8A5B), 6),
      (8, -42, Color(0xFF4CD4A0), 5),
      (-8, 46, Color(0xFFFFC84A), 5),
    ];
    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final d in dots)
            Transform.translate(
              offset: Offset(d.$1, d.$2),
              child: Container(
                width: d.$4,
                height: d.$4,
                decoration: BoxDecoration(color: d.$3, shape: BoxShape.circle),
              ),
            ),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFF3DDC97),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 46),
          ),
        ],
      ),
    );
  }
}
