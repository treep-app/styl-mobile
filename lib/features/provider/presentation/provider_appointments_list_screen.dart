import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import '../data/provider_demo_data.dart';
import 'widgets/provider_appointment_tile.dart';

/// Figma Total / Open / Closed Appointments — one filtered list screen.
class ProviderAppointmentsListScreen extends StatefulWidget {
  const ProviderAppointmentsListScreen({
    super.key,
    this.args = const ProviderApptListArgs(),
  });

  final ProviderApptListArgs args;

  @override
  State<ProviderAppointmentsListScreen> createState() =>
      _ProviderAppointmentsListScreenState();
}

class _ProviderAppointmentsListScreenState
    extends State<ProviderAppointmentsListScreen> {
  var _loading = true;
  String? _error;
  List<ProviderAppointment> _items = const [];
  late ProviderApptFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.args.filter;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _title {
    switch (_filter) {
      case ProviderApptFilter.total:
        return 'Total Appointments';
      case ProviderApptFilter.opened:
        return 'Open Appointments';
      case ProviderApptFilter.closed:
        return 'Closed Appointments';
    }
  }

  String? get _statusQuery {
    switch (_filter) {
      case ProviderApptFilter.total:
        return 'TOTAL';
      case ProviderApptFilter.opened:
        return 'OPENED';
      case ProviderApptFilter.closed:
        return 'CLOSED';
    }
  }

  Future<void> _setFilter(ProviderApptFilter filter) async {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context
          .read<AuthController>()
          .appointmentsApi
          .list(status: _statusQuery);
      if (!mounted) return;
      setState(() {
        _items = list.map(ProviderAppointment.fromDto).toList();
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
    final countLabel = _loading ? _title : '$_title (${_items.length})';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          countLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                for (final filter in ProviderApptFilter.values) ...[
                  if (filter != ProviderApptFilter.values.first)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _FilterChip(
                      label: switch (filter) {
                        ProviderApptFilter.total => 'Total',
                        ProviderApptFilter.opened => 'Open',
                        ProviderApptFilter.closed => 'Closed',
                      },
                      selected: _filter == filter,
                      onTap: () => _setFilter(filter),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: _loading
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
              : _items.isEmpty
                  ? const Center(child: Text('No appointments'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          return ProviderAppointmentTile(
                            appointment: _items[index],
                            onTap: () => _openAppointment(_items[index]),
                          );
                        },
                      ),
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
    return Material(
      color: selected ? const Color(0xFF003E6F) : const Color(0xFFF2F3F7),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFF003E6F),
            ),
          ),
        ),
      ),
    );
  }
}
