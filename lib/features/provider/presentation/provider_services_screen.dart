import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/constants/salon_service_catalog.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

/// Owner services hub — list, filter, add/edit (matches product screenshots).
class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({
    super.key,
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;

  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesScreenState();
}

class _ProviderServicesScreenState extends State<ProviderServicesScreen> {
  static const _green = Color(0xFF22C55E);

  var _loading = true;
  var _searching = false;
  String? _error;
  ShopDto? _shop;
  List<ServiceDto> _services = const [];
  int _teamCount = 1;
  String _filter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthController>();
      final mine = await auth.catalogApi.listMyShops();
      ShopDto? shop;
      if (widget.shopId != null) {
        for (final s in mine) {
          if (s.id == widget.shopId) {
            shop = s;
            break;
          }
        }
        shop ??= await auth.catalogApi.getShop(widget.shopId!);
      } else {
        shop = mine.where((s) => s.isOwner == true).firstOrNull ??
            (mine.isNotEmpty ? mine.first : null);
      }

      var services = const <ServiceDto>[];
      var teamCount = 1;
      final userId = auth.user?.id;
      final isOwner = shop?.isOwner == true;
      if (shop != null) {
        services = await auth.catalogApi.listServices(
          shop.id,
          includeInactive: true,
        );
        // Staff see services assigned to them.
        if (!isOwner && userId != null) {
          services = services
              .where((s) => s.assignedBarberIds.contains(userId))
              .toList();
        }
        try {
          final team = await auth.catalogApi.listSpecialists(
            shop.id,
            includePending: isOwner,
          );
          teamCount = team.isEmpty ? 1 : team.length;
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _shop = shop;
        _services = services;
        _teamCount = teamCount;
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

  List<ServiceDto> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    return _services.where((s) {
      if (_filter != 'All' && s.resolvedCategory != _filter) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          (s.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Map<String, List<ServiceDto>> get _grouped {
    final map = <String, List<ServiceDto>>{};
    for (final s in _filtered) {
      map.putIfAbsent(s.resolvedCategory, () => []).add(s);
    }
    return map;
  }

  int _countFor(String category) {
    if (category == 'All') return _services.length;
    return _services.where((s) => s.resolvedCategory == category).length;
  }

  Future<void> _openEditor({ServiceDto? service}) async {
    final shop = _shop;
    if (shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join or create a salon before adding services.'),
        ),
      );
      return;
    }
    final saved = await Navigator.of(context).pushNamed(
      AppRoutes.providerServiceEdit,
      arguments: ProviderServiceEditArgs(
        shopId: shop.id,
        service: service,
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _removeService(ServiceDto service) async {
    final shop = _shop;
    if (shop == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this service?'),
        content: Text(
          '“${service.name}” will be removed so customers can’t book it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AuthController>().catalogApi.deleteService(
            shop.id,
            service.id,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${service.name}” removed')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _finishOnboarding() async {
    await SessionStore().setProviderSetupStage('opening_hours');
    await SessionStore().setProviderSetupShopId(_shop?.id);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.providerSalonHours,
      (route) => false,
      arguments: SalonSetupArgs(
        shopId: _shop?.id,
        fromOnboarding: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = ['All', ...SalonServiceCatalog.categories];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (widget.fromOnboarding) {
                        _finishOnboarding();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Services',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _searching = !_searching),
                    icon: Icon(
                      _searching ? Icons.close : Icons.search,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Manage what customers can book.',
                style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
              ),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search services',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _shop == null ? null : () => _openEditor(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Add Service',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final label = chips[i];
                  final selected = _filter == label;
                  final count = _countFor(label);
                  return ChoiceChip(
                    label: Text('$label ($count)'),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = label),
                    selectedColor: _green,
                    backgroundColor: const Color(0xFFEEF0F5),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.brandPrimary,
                    ),
                    showCheckmark: false,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: _filtered.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(28),
                                  children: const [
                                    SizedBox(height: 40),
                                    Icon(
                                      Icons.content_cut_outlined,
                                      size: 42,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No services yet',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brandPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Add what your salon offers so customers can book.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                )
                              : ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    24,
                                  ),
                                  children: [
                                    for (final entry in _grouped.entries) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          entry.key,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.brandPrimary,
                                          ),
                                        ),
                                      ),
                                      for (final service in entry.value)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: _ServiceCard(
                                            service: service,
                                            professionals: service
                                                    .assignedBarberIds
                                                    .isNotEmpty
                                                ? service.assignedBarberIds.length
                                                : _teamCount,
                                            onTap: () =>
                                                _openEditor(service: service),
                                            onRemove: () =>
                                                _removeService(service),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                        ),
            ),
            if (widget.fromOnboarding)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: FilledButton(
                    onPressed: _finishOnboarding,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _services.isEmpty ? 'Skip for now' : 'Continue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.professionals,
    required this.onTap,
    required this.onRemove,
  });

  final ServiceDto service;
  final int professionals;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: service.imageUrl != null &&
                          service.imageUrl!.isNotEmpty
                      ? Image.network(
                          service.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${service.priceLabel} · ${service.durationMin} min',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$professionals professional${professionals == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
                    onSelected: (value) {
                      if (value == 'edit') onTap();
                      if (value == 'remove') onRemove();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(
                          'Remove',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: service.isActive
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF9CA3AF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        service.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: service.isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFFEDE9FE),
      child: const Icon(Icons.content_cut, color: AppColors.brandPrimary),
    );
  }
}
