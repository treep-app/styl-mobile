import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import '../data/provider_demo_data.dart';
import 'widgets/provider_appointment_tile.dart';

/// Appointments tab inside provider shell (opened + closed).
class ProviderAppointmentsTab extends StatefulWidget {
  const ProviderAppointmentsTab({super.key});

  @override
  State<ProviderAppointmentsTab> createState() =>
      _ProviderAppointmentsTabState();
}

class _ProviderAppointmentsTabState extends State<ProviderAppointmentsTab> {
  var _loading = true;
  String? _error;
  List<ProviderAppointment> _opened = const [];
  List<ProviderAppointment> _closed = const [];

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
    final api = context.read<AuthController>().appointmentsApi;
    try {
      final opened = await api.list(status: 'OPENED');
      final closed = await api.list(status: 'CLOSED');
      if (!mounted) return;
      setState(() {
        _opened = opened.map(ProviderAppointment.fromDto).toList();
        _closed = closed.map(ProviderAppointment.fromDto).toList();
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

  Future<void> _openAppointment(ProviderAppointment appointment) async {
    final changed = await showAppointmentDetailsSheet(
      context,
      appointment: appointment.dto,
    );
    if (changed && mounted) await _load();
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
                        Text(_error!),
                        TextButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        const Text(
                          'Appointments',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Open',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_opened.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No open appointments'),
                          )
                        else
                          ..._opened.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ProviderAppointmentTile(
                                appointment: a,
                                onTap: () => _openAppointment(a),
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        const Text(
                          'Closed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_closed.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('No closed appointments'),
                          )
                        else
                          ..._closed.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ProviderAppointmentTile(
                                appointment: a,
                                onTap: () => _openAppointment(a),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
