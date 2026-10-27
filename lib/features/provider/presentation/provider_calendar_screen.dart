import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import '../../customer/presentation/looks_ui.dart';
import '../data/provider_demo_data.dart';
import 'widgets/provider_looks_chrome.dart';

/// Looksy Calendar tab — week strip + that day's bookings.
class ProviderCalendarScreen extends StatefulWidget {
  const ProviderCalendarScreen({super.key});

  @override
  State<ProviderCalendarScreen> createState() => ProviderCalendarScreenState();
}

class ProviderCalendarScreenState extends State<ProviderCalendarScreen> {
  var _loading = true;
  String? _error;
  List<AppointmentDto> _all = const [];
  late DateTime _weekStart;
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = providerDay(now);
    _weekStart = providerWeekStart(now);
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<AuthController>().appointmentsApi.list();
      if (!mounted) return;
      setState(() {
        _all = list;
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

  List<AppointmentDto> get _dayItems {
    final items = _all
        .where((a) => providerSameDay(a.scheduledStart.toLocal(), _selected))
        .toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    return items;
  }

  static const _months = [
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
  static const _dows = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_months[_weekStart.month - 1]} ${_weekStart.year}';

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Calendar',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: LooksUi.ink,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _weekStart =
                            _weekStart.subtract(const Duration(days: 7));
                      });
                    },
                    icon: const Icon(Icons.chevron_left_rounded, color: LooksUi.ink),
                  ),
                  IconButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _weekStart = _weekStart.add(const Duration(days: 7));
                      });
                    },
                    icon: const Icon(Icons.chevron_right_rounded, color: LooksUi.ink),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: LooksUi.muted,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: List.generate(7, (i) {
                  final day = _weekStart.add(Duration(days: i));
                  final selected = providerSameDay(day, _selected);
                  final today = providerSameDay(day, DateTime.now());
                  final count = _all
                      .where(
                        (a) =>
                            a.status != 'CANCELLED' &&
                            providerSameDay(a.scheduledStart.toLocal(), day),
                      )
                      .length;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Material(
                        color: selected ? LooksUi.purple : LooksUi.chipIdle,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selected = day);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Text(
                                  _dows[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : LooksUi.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: selected ? Colors.white : LooksUi.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: count == 0
                                        ? Colors.transparent
                                        : selected
                                            ? Colors.white
                                            : today
                                                ? LooksUi.purple
                                                : const Color(0xFFC8C4D8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const AppointmentsSkeleton()
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: reload,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: LooksUi.purple,
                          onRefresh: reload,
                          child: _dayItems.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: const [
                                    SizedBox(height: 80),
                                    Icon(
                                      Icons.event_available_outlined,
                                      size: 40,
                                      color: LooksUi.navGray,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No bookings this day',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: LooksUi.muted,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    12,
                                    20,
                                    24,
                                  ),
                                  itemCount: _dayItems.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    final a = _dayItems[i];
                                    return _BookingCard(
                                      appointment: a,
                                      onTap: () async {
                                        final mapped =
                                            ProviderAppointment.fromDto(a);
                                        final changed =
                                            await showAppointmentDetailsSheet(
                                          context,
                                          appointment: mapped.dto,
                                        );
                                        if (changed && mounted) await reload();
                                      },
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

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.appointment, required this.onTap});

  final AppointmentDto appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LooksUi.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: appointment.isCancelled
                        ? const Color(0xFFD64545)
                        : appointment.isCompleted
                            ? const Color(0xFF2F9E6B)
                            : LooksUi.purple,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.clientName ?? 'Client',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: LooksUi.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appointment.serviceName ?? 'Appointment',
                        style: const TextStyle(
                          fontSize: 13,
                          color: LooksUi.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      appointment.timeRangeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: LooksUi.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: appointment.isCancelled
                            ? const Color(0xFFD64545)
                            : LooksUi.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
