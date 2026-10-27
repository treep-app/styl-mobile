import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/payments/booking_fee.dart';
import '../../../core/payments/stripe_payments.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';
import '../../../widgets/styl_skeleton.dart';
import 'customer_shell_tabs.dart';
import 'widgets/booking_stepper.dart';

/// Full Figma booking flow: Book → Payment (+ fee modal) → Finished.
class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({
    super.key,
    this.args = const BookAppointmentArgs(
      shopId: '',
      salonName: 'Eliza Burke Hair saloon',
      address: '301 Dorty walks, Stockton, California',
    ),
  });

  final BookAppointmentArgs args;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  static const _fallbackAvatar =
      'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=300&q=80';

  var _step = 0;
  late DateTime _month;
  late DateTime _selectedDate;
  var _specialistIndex = 0;
  SlotDto? _selectedSlot;
  var _paymentMethod = 'Wallet';
  String? _selectedCardId;
  var _submitting = false;
  String? _busyMessage;
  var _loadingSpecialists = true;
  var _loadingSlots = false;
  String? _loadError;
  List<_Specialist> _specialists = const [];
  List<SlotDto> _slots = const [];
  List<PaymentMethodDto> _cards = const [];
  String? _createdAppointmentId;
  String? _pendingAppointmentId;
  String _paymentStatus = 'UNPAID';
  String? _checkoutMessage;

  double get _bookingFee => computeStylBookingFee(widget.args.priceAmount);

  String get _bookingFeeLabel => stylFeeLabel(_bookingFee);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    if (_selectedDate.weekday > 5) {
      _selectedDate = _selectedDate.add(const Duration(days: 2));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSpecialists();
      _loadCards();
    });
  }

  String get _specialistName =>
      _specialists.isEmpty ? 'Specialist' : _specialists[_specialistIndex].name;

  String? get _specialistId =>
      _specialists.isEmpty ? null : _specialists[_specialistIndex].id;

  String get _dateLabel {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, ${_selectedDate.year}';
  }

  String get _slotDisplay => _selectedSlot?.label ?? '09:00-10:00AM';

  String get _dateQuery {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadSpecialists() async {
    if (widget.args.shopId.isEmpty) {
      setState(() {
        _loadingSpecialists = false;
        _loadError = 'Missing shop';
      });
      return;
    }
    setState(() {
      _loadingSpecialists = true;
      _loadError = null;
    });
    try {
      final list = await context
          .read<AuthController>()
          .catalogApi
          .listSpecialists(widget.args.shopId);
      if (!mounted) return;
      var index = 0;
      final preferred = widget.args.preferredBarberUserId;
      if (preferred != null) {
        final i = list.indexWhere((s) => s.id == preferred);
        if (i >= 0) index = i;
      }
      setState(() {
        _specialists = list
            .map(
              (s) => _Specialist(
                id: s.id,
                name: s.fullName ?? 'Barber',
                image: s.avatarUrl ?? _fallbackAvatar,
                isOnline: s.isOnline,
              ),
            )
            .toList();
        _specialistIndex = _specialists.isEmpty ? 0 : index;
        _loadingSpecialists = false;
      });
      await _loadSlots();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = friendlyErrorMessage(e);
        _loadingSpecialists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = friendlyErrorMessage(e);
        _loadingSpecialists = false;
      });
    }
  }

  Future<void> _loadSlots() async {
    final barberId = _specialistId;
    if (barberId == null) {
      setState(() {
        _slots = const [];
        _selectedSlot = null;
      });
      return;
    }
    setState(() {
      _loadingSlots = true;
      _selectedSlot = null;
    });
    try {
      final slots = await context.read<AuthController>().catalogApi.listSlots(
            barberId: barberId,
            date: _dateQuery,
          );
      if (!mounted) return;
      setState(() {
        _slots = slots.where((s) => s.available).toList();
        _loadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _slots = const [];
        _loadingSlots = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slots = const [];
        _loadingSlots = false;
      });
    }
  }

  Future<void> _loadCards() async {
    try {
      final methods =
          await context.read<AuthController>().paymentsApi.listMethods();
      if (!mounted) return;
      setState(() => _cards = methods);
    } catch (_) {}
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _step -= 1);
  }

  void _onBookContinue() {
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot.')),
      );
      return;
    }
    if (_specialistId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a specialist.')),
      );
      return;
    }
    setState(() => _step = 1);
  }

  String _mapPaymentMethod() {
    if (_paymentMethod == 'Cash') return 'CASH';
    if (_paymentMethod == 'PayPal') return 'PAYPAL';
    if (_paymentMethod == 'Card' &&
        _selectedCardId != null &&
        _selectedCardId!.startsWith('pm_')) {
      return 'CARD';
    }
    return 'WALLET';
  }

  bool get _payAtSalon => _paymentMethod == 'Cash';

  double get _dueNow => stylAmountDueNow(
        payAtSalon: _payAtSalon,
        serviceAmount: widget.args.priceAmount,
      );

  String get _dueNowLabel => stylFeeLabel(_dueNow);

  Future<void> _onConfirmPayment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) => _BookingFeeDialog(
        feeLabel: _bookingFeeLabel,
        dueNowLabel: _dueNowLabel,
        payAtSalon: _payAtSalon,
      ),
    );
    if (confirmed != true || !mounted) return;

    final barberId = _specialistId;
    final slot = _selectedSlot;
    if (barberId == null || slot == null) return;

    setState(() {
      _submitting = true;
      _busyMessage = 'Creating your booking…';
    });

    final auth = context.read<AuthController>();
    final payMethod = _mapPaymentMethod();

    void clearBusy() {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _busyMessage = null;
      });
    }

    void finishBooking({
      required AppointmentDto appointment,
      required String? checkoutMessage,
    }) {
      if (appointment.paymentStatus != 'PAID') {
        clearBusy();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pay the STYL booking fee to confirm this booking.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _createdAppointmentId = appointment.id;
        _paymentStatus = appointment.paymentStatus;
        _checkoutMessage = checkoutMessage;
        _step = 2;
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
          finishBooking(
            appointment: created,
            checkoutMessage: 'Booking fee paid. Thank you!',
          );
          return;
        }
      } else {
        created = await auth.appointmentsApi.create(
          shopId: widget.args.shopId,
          barberUserId: barberId,
          scheduledStart: slot.startAt,
          serviceId: widget.args.serviceId,
          paymentMethod: payMethod,
        );
        _pendingAppointmentId = created.id;
      }
      if (!mounted) return;
      setState(() => _busyMessage = 'Taking payment…');

      final paid = await auth.appointmentsApi.pay(
        id: created.id,
        paymentMethod: payMethod,
        paymentMethodId: payMethod == 'CARD' ? _selectedCardId : null,
      );
      if (!mounted) return;

      if (paid.appointment.paymentStatus == 'PAID') {
        finishBooking(
          appointment: paid.appointment,
          checkoutMessage: 'Booking fee paid. Pay the service at the salon.',
        );
        return;
      }

      // Wallet / saved-card Payment Sheet (3DS).
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
            const SnackBar(
              content: Text(
                'Stripe is misconfigured on the server. Check publishable key.',
              ),
            ),
          );
          return;
        }

        setState(() => _busyMessage = 'Opening Stripe…');
        await StripePayments.configure(publishableKey: publishableKey);
        if (!mounted) return;

        // Hide our overlay so Stripe's sheet is visible, then wait a frame.
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

        final confirmedAppt = await auth.appointmentsApi.confirmPayment(
          id: paid.appointment.id,
          paymentIntentId: paymentIntentId,
        );
        if (!mounted) return;
        if (confirmedAppt.paymentStatus != 'PAID') {
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
        finishBooking(
          appointment: confirmedAppt,
          checkoutMessage: 'Booking fee paid. Pay the service at the salon.',
        );
        return;
      }

      // PayPal (and similar): open external approval URL.
      if (paid.checkout.requiresAction &&
          paid.checkout.checkoutUrl != null &&
          paid.checkout.checkoutUrl!.isNotEmpty) {
        final uri = Uri.parse(paid.checkout.checkoutUrl!);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!mounted) return;
        if (!launched) {
          clearBusy();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open ${paid.checkout.provider} checkout.',
              ),
            ),
          );
          return;
        }
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
        SnackBar(
          content: Text(
            paid.checkout.message.isNotEmpty
                ? paid.checkout.message
                : 'Pay the STYL booking fee to confirm this booking.',
          ),
        ),
      );
    } on StripeException catch (e) {
      clearBusy();
      if (!mounted) return;
      final raw = e.error.localizedMessage ??
          e.error.message ??
          'Stripe payment failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyErrorMessage(raw)),
          duration: const Duration(seconds: 5),
        ),
      );
    } on MissingPluginException {
      clearBusy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stripe plugin not ready. Fully stop the app and run flutter run again (not hot restart).',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } on ApiException catch (e) {
      clearBusy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      clearBusy();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: ${friendlyErrorMessage(e)}'),
        ),
      );
    }
  }

  void _bookMore() {
    setState(() {
      _step = 0;
      _selectedSlot = null;
      _createdAppointmentId = null;
      _pendingAppointmentId = null;
      _paymentStatus = 'UNPAID';
      _checkoutMessage = null;
    });
  }

  void _goToAppointments() {
    CustomerShellTabs.goTo(CustomerShellTabs.appointments);
    Navigator.of(context).popUntil(
      (route) =>
          route.settings.name == AppRoutes.customerShell || route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
          children: [
            _BookingAppBar(onBack: _goBack),
            BookingStepper(currentStep: _step),
            Expanded(
              child: _loadingSpecialists
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: SalonListSkeleton(count: 4),
                    )
                  : _loadError != null && _specialists.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loadError!),
                              TextButton(
                                onPressed: _loadSpecialists,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: switch (_step) {
                            0 => _BookStep(
                                key: const ValueKey('book'),
                                month: _month,
                                selectedDate: _selectedDate,
                                specialists: _specialists,
                                specialistIndex: _specialistIndex,
                                slots: _slots,
                                loadingSlots: _loadingSlots,
                                selectedSlot: _selectedSlot,
                                onPrevMonth: () => setState(() {
                                  _month =
                                      DateTime(_month.year, _month.month - 1);
                                }),
                                onNextMonth: () => setState(() {
                                  _month =
                                      DateTime(_month.year, _month.month + 1);
                                }),
                                onSelectDate: (date) {
                                  setState(() => _selectedDate = date);
                                  _loadSlots();
                                },
                                onSelectSpecialist: (index) {
                                  setState(() => _specialistIndex = index);
                                  _loadSlots();
                                },
                                onSelectSlot: (slot) =>
                                    setState(() => _selectedSlot = slot),
                              ),
                            1 => _PaymentStep(
                                key: const ValueKey('payment'),
                                args: widget.args,
                                specialist: _specialistName,
                                slot: _slotDisplay,
                                dateLabel: _dateLabel,
                                paymentMethod: _paymentMethod,
                                cards: _cards,
                                selectedCardId: _selectedCardId,
                                feeLabel: _bookingFeeLabel,
                                dueNowLabel: _dueNowLabel,
                                onPaymentChanged: (value) => setState(() {
                                  _paymentMethod = value;
                                  _selectedCardId = null;
                                }),
                                onCardChanged: (id) => setState(() {
                                  _selectedCardId = id;
                                  _paymentMethod = 'Card';
                                }),
                                onCardsRefresh: _loadCards,
                              ),
                            _ => _FinishedStep(
                                key: const ValueKey('finished'),
                                args: widget.args,
                                specialist: _specialistName,
                                slot: _slotDisplay,
                                dateLabel: _dateLabel,
                                appointmentId: _createdAppointmentId,
                                paymentStatus: _paymentStatus,
                                checkoutMessage: _checkoutMessage,
                                paymentMethodLabel: _paymentMethod,
                              ),
                          },
                        ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: switch (_step) {
                0 => StylPrimaryButton(
                    label: 'Book Appointment',
                    onPressed: _onBookContinue,
                  ),
                1 => StylPrimaryButton(
                    label: _payAtSalon
                        ? 'Pay $_bookingFeeLabel booking fee'
                        : 'Pay $_dueNowLabel now',
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _onConfirmPayment,
                  ),
                _ => Column(
                    children: [
                      StylPrimaryButton(
                        label: 'Book more Appointment',
                        onPressed: _bookMore,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _goToAppointments,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.brandPrimary,
                            side: const BorderSide(
                              color: AppColors.brandPrimary,
                            ),
                            backgroundColor: const Color(0xFFE8EEF4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                          ),
                          child: const Text(
                            'Go to Appointment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              },
            ),
          ],
        ),
            if (_submitting && (_busyMessage?.isNotEmpty ?? false))
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _busyMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please wait — do not leave this screen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
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
    );
  }
}

class _Specialist {
  const _Specialist({
    required this.id,
    required this.name,
    required this.image,
    this.isOnline = false,
  });

  final String id;
  final String name;
  final String image;
  final bool isOnline;
}

class _BookingAppBar extends StatelessWidget {
  const _BookingAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
          const Expanded(
            child: Text(
              'Book Appointment',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _BookStep extends StatelessWidget {
  const _BookStep({
    super.key,
    required this.month,
    required this.selectedDate,
    required this.specialists,
    required this.specialistIndex,
    required this.slots,
    required this.loadingSlots,
    required this.selectedSlot,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDate,
    required this.onSelectSpecialist,
    required this.onSelectSlot,
  });

  final DateTime month;
  final DateTime selectedDate;
  final List<_Specialist> specialists;
  final int specialistIndex;
  final List<SlotDto> slots;
  final bool loadingSlots;
  final SlotDto? selectedSlot;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<int> onSelectSpecialist;
  final ValueChanged<SlotDto> onSelectSlot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _Card(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onPrevMonth,
                    icon: const Icon(Icons.chevron_left, color: Color(0xFFBDBDBD)),
                  ),
                  Expanded(
                    child: Text(
                      _monthTitle(month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onNextMonth,
                    icon: const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _WeekStrip(
                month: month,
                selectedDate: selectedDate,
                onSelect: onSelectDate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Available Specialists',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'view more',
                      style: TextStyle(
                        color: AppColors.brandAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (specialists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No specialists available'),
                )
              else
                SizedBox(
                height: 114,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: specialists.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item = specialists[index];
                    final selected = index == specialistIndex;
                    return GestureDetector(
                      onTap: () => onSelectSpecialist(index),
                      child: SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.image,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 64,
                                      height: 64,
                                      color: AppColors.lightSurfaceVariant,
                                      child: const Icon(Icons.person),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: item.isOnline
                                          ? const Color(0xFF34C759)
                                          : const Color(0xFFBDBDBD),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                if (selected)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: CustomPaint(
                                      size: const Size(22, 22),
                                      painter: _CornerCheckPainter(),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available slot',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (loadingSlots)
                const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (slots.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No slots for this date'),
                )
              else
                SizedBox(
                height: 168,
                child: GridView.builder(
                  itemCount: slots.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3.2,
                  ),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final selected = slot.startAt == selectedSlot?.startAt;
                    return GestureDetector(
                      onTap: () => onSelectSlot(slot),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.brandAccent
                              : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? AppColors.brandAccent
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Text(
                          slot.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _monthTitle(DateTime month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[month.month - 1]}, ${month.year}';
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.month,
    required this.selectedDate,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final start = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Row(
      children: List.generate(7, (index) {
        final date = DateTime(start.year, start.month, start.day + index);
        final isSelected = date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day;
        final isPast = date.isBefore(todayDate);

        return Expanded(
          child: GestureDetector(
            onTap: isPast ? null : () => onSelect(date),
            child: Column(
              children: [
                Text(
                  labels[index],
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB0B0B0),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.brandAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? const Color(0xFFD0D0D0)
                              : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _CornerCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.brandAccent);
    final check = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.42, size.height * 0.28),
      Offset(size.width * 0.55, size.height * 0.42),
      check,
    );
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.42),
      Offset(size.width * 0.78, size.height * 0.18),
      check,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    super.key,
    required this.args,
    required this.specialist,
    required this.slot,
    required this.dateLabel,
    required this.paymentMethod,
    required this.cards,
    required this.selectedCardId,
    required this.feeLabel,
    required this.dueNowLabel,
    required this.onPaymentChanged,
    required this.onCardChanged,
    required this.onCardsRefresh,
  });

  final BookAppointmentArgs args;
  final String specialist;
  final String slot;
  final String dateLabel;
  final String paymentMethod;
  final List<PaymentMethodDto> cards;
  final String? selectedCardId;
  final String feeLabel;
  final String dueNowLabel;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onCardChanged;
  final Future<void> Function() onCardsRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _Card(
          child: Column(
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      args.imageUrl,
                      width: 72,
                      height: 56,
                      fit: BoxFit.cover,
                      color: Colors.grey,
                      colorBlendMode: BlendMode.saturation,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 56,
                        color: AppColors.lightSurfaceVariant,
                        child: const Icon(Icons.storefront),
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
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          args.address,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A8A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  const Text(
                    'Specialist',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  const Icon(Icons.person_outline, size: 16, color: Color(0xFF9E9E9E)),
                  const SizedBox(width: 4),
                  Text(specialist),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    slot.replaceAll(' ', ''),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    dateLabel,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFD0D0D0)),
              ),
              Row(
                children: [
                  Text(args.service),
                  const Spacer(),
                  Text(
                    args.priceLabel,
                    style: const TextStyle(
                      color: AppColors.brandAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('STYL booking fee'),
                  const Spacer(),
                  Text(
                    feeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  paymentMethod == 'Cash'
                      ? 'Pay $feeLabel now to confirm. Service is paid at the salon.'
                      : 'Pay $dueNowLabel now (service + $feeLabel STYL fee).',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment Methods',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _Card(
          child: Column(
            children: [
              _PaymentTile(
                label: 'Cash at salon',
                subtitle: 'Service paid at salon · $feeLabel fee due now',
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF2E7D32),
                selected: paymentMethod == 'Cash',
                onTap: () => onPaymentChanged('Cash'),
              ),
              _PaymentTile(
                label: 'PayPal',
                subtitle: 'Coming soon',
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF9E9E9E),
                selected: false,
                enabled: false,
                onTap: () {},
              ),
              _PaymentTile(
                label: 'Wallet',
                subtitle: 'Pay service + $feeLabel fee now',
                icon: Icons.account_balance_wallet,
                iconColor: const Color(0xFF635BFF),
                selected: paymentMethod == 'Wallet',
                onTap: () => onPaymentChanged('Wallet'),
                showDivider: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          child: Column(
            children: [
              if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No saved cards'),
                )
              else
                ...cards.map(
                  (card) => _CardTile(
                    brand: card.brand,
                    number: '**** **** **** ${card.last4}',
                    selected: selectedCardId == card.id,
                    onTap: () => onCardChanged(card.id),
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                tileColor: Colors.transparent,
                title: const Text(
                  'Add new card',
                  style: TextStyle(color: Color(0xFF9E9E9E)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final result = await Navigator.of(context).pushNamed(
                    AppRoutes.addCard,
                  );
                  if (result != null && context.mounted) {
                    await onCardsRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Card added')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _FinishedStep extends StatelessWidget {
  const _FinishedStep({
    super.key,
    required this.args,
    required this.specialist,
    required this.slot,
    required this.dateLabel,
    required this.paymentStatus,
    this.appointmentId,
    this.checkoutMessage,
    this.paymentMethodLabel,
  });

  final BookAppointmentArgs args;
  final String specialist;
  final String slot;
  final String dateLabel;
  final String paymentStatus;
  final String? appointmentId;
  final String? checkoutMessage;
  final String? paymentMethodLabel;

  bool get _isPaid => paymentStatus.toUpperCase() == 'PAID';

  String get _statusTitle {
    if (_isPaid) return 'PAID';
    final method = (paymentMethodLabel ?? '').toLowerCase();
    if (method.contains('cash')) return 'UNPAID';
    return 'PENDING';
  }

  String get _statusSubtitle {
    if (_isPaid) return 'THANK YOU';
    if ((paymentMethodLabel ?? '').toLowerCase().contains('cash')) {
      return 'PAY AT\nSALON';
    }
    return 'AWAITING\nPAYMENT';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.salonName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Color(0xFF9E9E9E),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                args.address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appointmentId != null
                              ? 'ID $appointmentId'
                              : 'ID pending',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB0B0B0),
                          ),
                        ),
                        if (checkoutMessage != null &&
                            checkoutMessage!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            checkoutMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _isPaid
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFE65100),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isPaid
                            ? AppColors.brandPrimary
                            : const Color(0xFFE65100),
                        width: 3,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _statusSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: _isPaid
                                ? AppColors.brandPrimary
                                : const Color(0xFFE65100),
                            height: 1.1,
                          ),
                        ),
                        Text(
                          _statusTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _isPaid
                                ? AppColors.brandPrimary
                                : const Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hair Stylist',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 16,
                              color: Color(0xFF9E9E9E),
                            ),
                            const SizedBox(width: 4),
                            Text(specialist),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        slot.replaceAll(' ', ''),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookingFeeDialog extends StatelessWidget {
  const _BookingFeeDialog({
    required this.feeLabel,
    required this.dueNowLabel,
    required this.payAtSalon,
  });

  final String feeLabel;
  final String dueNowLabel;
  final bool payAtSalon;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              payAtSalon
                  ? 'Pay a STYL booking fee of $feeLabel to confirm.\nThe service is paid at the salon.'
                  : 'Pay $dueNowLabel now to confirm\n(service + $feeLabel STYL fee).',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandAccent,
                      backgroundColor: const Color(0xFFFFE8E0),
                      side: const BorderSide(color: AppColors.brandAccent),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandAccent,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Confirm'),
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

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material (not Container) so ListTile ink/splash paints on this surface.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
    this.showDivider = true,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.55,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            tileColor: Colors.transparent,
            onTap: enabled
                ? onTap
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label is coming soon'),
                      ),
                    );
                  },
            leading: Icon(icon, color: iconColor),
            title: Text(
              label,
              style: TextStyle(
                color: enabled ? null : const Color(0xFF8A8A8A),
              ),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brandAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            trailing: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: !enabled
                  ? const Color(0xFFE0E0E0)
                  : selected
                      ? AppColors.brandPrimary
                      : const Color(0xFFBDBDBD),
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.brand,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  final String brand;
  final String number;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          tileColor: Colors.transparent,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.lightSurfaceVariant,
            child: Text(
              brand[0],
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
          title: Text(number),
          subtitle: Text(brand),
          trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.brandPrimary : const Color(0xFFBDBDBD),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
