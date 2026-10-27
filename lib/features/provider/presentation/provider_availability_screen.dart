import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../customer/presentation/looks_ui.dart';

/// Availability toggle + the professional's own working hours.
class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  State<ProviderAvailabilityScreen> createState() =>
      _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState
    extends State<ProviderAvailabilityScreen> {
  static const _days = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  var _loading = true;
  var _toggling = false;
  String? _error;
  ShopDto? _shop;
  List<WorkingHourDto> _hours = const [];

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
    try {
      final auth = context.read<AuthController>();
      final mine = await auth.catalogApi.listMyShops();
      ShopDto? shop = mine.where((s) => s.isOwner == true).firstOrNull ??
          (mine.isNotEmpty ? mine.first : null);

      List<WorkingHourDto> hours = const [];
      try {
        hours = await auth.catalogApi.listMyWorkingHours();
      } catch (_) {}

      if (hours.isEmpty && shop != null) {
        shop = await auth.catalogApi.getShop(shop.id);
        hours = shop.workingHours;
      }

      if (!mounted) return;
      setState(() {
        _shop = shop;
        _hours = hours;
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

  Future<void> _toggle(bool value) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      await context.read<AuthController>().setAvailability(value);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update availability.')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _editHours() async {
    final changed = await Navigator.of(context).pushNamed(
      AppRoutes.providerSalonHours,
      arguments: SalonSetupArgs(shopId: _shop?.id),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final available =
        context.watch<AuthController>().user?.isAvailableNow ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: LooksUi.ink,
        title: const Text(
          'Availability',
          style: TextStyle(fontWeight: FontWeight.w800, color: LooksUi.ink),
        ),
        actions: [
          TextButton(
            onPressed: _editHours,
            child: const Text(
              'Edit hours',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: LooksUi.purple,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: LooksUi.purple),
            )
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
                  color: LooksUi.purple,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: LooksUi.purpleSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.only(left: 4),
                          title: const Text(
                            'Available now',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: LooksUi.ink,
                            ),
                          ),
                          subtitle: Text(
                            available
                                ? 'Clients can book you today'
                                : 'You appear as unavailable',
                            style: const TextStyle(color: LooksUi.muted),
                          ),
                          value: available,
                          activeThumbColor: LooksUi.purple,
                          onChanged: _toggling ? null : _toggle,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'My working hours',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: LooksUi.ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _editHours,
                            child: const Text('Edit'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_hours.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: LooksUi.hairline),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No hours set yet. Add your schedule so clients can book you.',
                                style: TextStyle(color: LooksUi.muted),
                              ),
                              const SizedBox(height: 10),
                              FilledButton(
                                onPressed: _editHours,
                                style: FilledButton.styleFrom(
                                  backgroundColor: LooksUi.purple,
                                ),
                                child: const Text('Set working hours'),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._hours.map((h) {
                          final day = (h.weekday >= 0 && h.weekday < 7)
                              ? _days[h.weekday]
                              : 'Day ${h.weekday}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: LooksUi.hairline),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: LooksUi.ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${h.startTime.substring(0, 5)} – ${h.endTime.substring(0, 5)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: LooksUi.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
