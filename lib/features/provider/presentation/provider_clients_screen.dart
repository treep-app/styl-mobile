import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../../widgets/styl_skeleton.dart';
import '../../appointments/presentation/appointment_details_sheet.dart';
import '../../customer/presentation/looks_ui.dart';
import 'widgets/provider_looks_chrome.dart';

class _ClientRow {
  const _ClientRow({
    required this.keyId,
    required this.name,
    required this.visits,
    required this.last,
    this.avatar,
    this.phone,
  });

  final String keyId;
  final String name;
  final int visits;
  final AppointmentDto last;
  final String? avatar;
  final String? phone;
}

/// Unique clients from live appointments.
class ProviderClientsScreen extends StatefulWidget {
  const ProviderClientsScreen({super.key});

  @override
  State<ProviderClientsScreen> createState() => ProviderClientsScreenState();
}

class ProviderClientsScreenState extends State<ProviderClientsScreen> {
  var _loading = true;
  String? _error;
  List<_ClientRow> _clients = const [];

  @override
  void initState() {
    super.initState();
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
      final map = <String, List<AppointmentDto>>{};
      for (final a in list) {
        if (a.status == 'CANCELLED') continue;
        final key = a.clientUserId ??
            a.clientPhone ??
            a.clientName ??
            a.id;
        map.putIfAbsent(key, () => []).add(a);
      }
      final rows = map.entries.map((e) {
        final visits = [...e.value]
          ..sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
        final last = visits.first;
        return _ClientRow(
          keyId: e.key,
          name: last.clientName ?? 'Client',
          visits: visits.length,
          last: last,
          avatar: last.clientAvatar,
          phone: last.clientPhone,
        );
      }).toList()
        ..sort((a, b) => b.last.scheduledStart.compareTo(a.last.scheduledStart));
      setState(() {
        _clients = rows;
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

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return ProviderLooksPage(
      title: 'Clients',
      subtitle: _loading ? null : '${_clients.length} people',
      onBack: canPop ? () => Navigator.of(context).maybePop() : null,
      child: _loading
          ? const AppointmentsSkeleton()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(onPressed: reload, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: LooksUi.purple,
                  onRefresh: reload,
                  child: _clients.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Icon(
                              Icons.people_outline_rounded,
                              size: 40,
                              color: LooksUi.navGray,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No clients yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LooksUi.muted,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: _clients.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final c = _clients[i];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => showAppointmentDetailsSheet(
                                  context,
                                  appointment: c.last,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: LooksUi.hairline),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        StylAvatar(
                                          size: 48,
                                          imageUrl: c.avatar,
                                          name: c.name,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                c.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: LooksUi.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${c.visits} ${c.visits == 1 ? 'visit' : 'visits'} · last ${c.last.dateLabel}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: LooksUi.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: LooksUi.navGray,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
