import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import '../data/provider_demo_data.dart';
import 'widgets/provider_appointment_tile.dart';

/// Salon-facing barber profile: hours, live status, assigned bookings.
class BarberRosterDetailScreen extends StatefulWidget {
  const BarberRosterDetailScreen({super.key, required this.args});

  final ProviderBarberDetailArgs args;

  @override
  State<BarberRosterDetailScreen> createState() =>
      _BarberRosterDetailScreenState();
}

class _BarberRosterDetailScreenState extends State<BarberRosterDetailScreen> {
  static const _dayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  late SpecialistDto? _barber = widget.args.specialist;
  List<AppointmentDto> _appointments = const [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final catalog = context.read<AuthController>().catalogApi;
    try {
      final member = await catalog.getShopMember(
        shopId: widget.args.shopId,
        barberUserId: widget.args.barberUserId,
      );
      final appointments = await catalog.listMemberAppointments(
        shopId: widget.args.shopId,
        barberUserId: widget.args.barberUserId,
      );
      if (!mounted) return;
      setState(() {
        _barber = member;
        _appointments = appointments;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load barber details.';
        _loading = false;
      });
    }
  }

  Color get _statusColor {
    final barber = _barber;
    if (barber == null) return PresenceAvatar.offlineGray;
    if (barber.isBusy) return PresenceAvatar.busyOrange;
    if (barber.isOnline) return PresenceAvatar.onlineGreen;
    return PresenceAvatar.offlineGray;
  }

  List<AppointmentDto> get _todayOpen {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _appointments.where((a) {
      final local = a.scheduledStart.toLocal();
      return a.isOpen && !local.isBefore(start) && local.isBefore(end);
    }).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  }

  List<AppointmentDto> get _upcoming {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return _appointments.where((a) {
      return a.isOpen && !a.scheduledStart.toLocal().isBefore(tomorrow);
    }).toList()
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  }

  String _hourLine(WorkingHourDto h) {
    String fmt(String t) => t.length >= 5 ? t.substring(0, 5) : t;
    final day = (h.weekday >= 0 && h.weekday < _dayNames.length)
        ? _dayNames[h.weekday]
        : 'Day ${h.weekday}';
    return '$day  ${fmt(h.startTime)}–${fmt(h.endTime)}';
  }

  Future<void> _openAppointment(AppointmentDto appointment) async {
    final changed = await showAppointmentDetailsSheet(
      context,
      appointment: appointment,
    );
    if (changed && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final barber = _barber;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Barber',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111111),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: AppColors.brandPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (widget.args.isOwner)
            TextButton(
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.providerManageSalon,
                  arguments: widget.args.shopId,
                );
              },
              child: const Text('Edit salon'),
            ),
        ],
      ),
      body: _loading && barber == null
          ? const SalonListSkeleton(count: 4)
          : _error != null && barber == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      if (barber != null) ...[
                        Row(
                          children: [
                            PresenceAvatar(
                              size: 72,
                              imageUrl: barber.avatarUrl,
                              name: barber.fullName,
                              isOnline: barber.isOnline,
                              isBusy: barber.isBusy,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    barber.fullName ?? 'Barber',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    barber.roleSpecialtyLabel,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFF8A8A8A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        barber.statusCaption,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(label: 'Today  ${barber.todayScheduleLabel}'),
                            if (barber.hoursLabel != null)
                              _Chip(label: barber.hoursLabel!),
                            if (!barber.isOnboarded)
                              const _Chip(label: 'Unlinked'),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Contact',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          value: barber.phone ?? '—',
                        ),
                        _InfoRow(
                          icon: Icons.mail_outline,
                          value: (barber.email?.trim().isNotEmpty == true)
                              ? barber.email!
                              : 'No email yet',
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Weekly schedule',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (barber.workingHours.isEmpty)
                          const Text(
                            'No hours set — default slots still apply.',
                            style: TextStyle(color: Color(0xFF8A8A8A)),
                          )
                        else
                          ...barber.workingHours.map(
                            (h) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _hourLine(h),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Today’s appointments',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_todayOpen.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'No bookings today',
                            style: TextStyle(color: Color(0xFF8A8A8A)),
                          ),
                        )
                      else
                        ..._todayOpen.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ProviderAppointmentTile(
                              appointment: ProviderAppointment.fromDto(a),
                              onTap: () => _openAppointment(a),
                            ),
                          ),
                        ),
                      if (_upcoming.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Upcoming',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._upcoming.take(6).map(
                              (a) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ProviderAppointmentTile(
                                  appointment: ProviderAppointment.fromDto(a),
                                  onTap: () => _openAppointment(a),
                                ),
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF575757),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14.5, color: Color(0xFF111111)),
            ),
          ),
        ],
      ),
    );
  }
}
