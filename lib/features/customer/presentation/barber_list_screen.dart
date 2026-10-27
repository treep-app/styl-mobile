import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/salon_list_card.dart';
import '../../../widgets/styl_skeleton.dart';
import '../data/customer_demo_data.dart';
import 'filter_sheet.dart';

/// Figma "Barber list" — freelancers or shops depending on [args.mode].
class BarberListScreen extends StatefulWidget {
  const BarberListScreen({super.key, required this.args});

  final BarberListArgs args;

  @override
  State<BarberListScreen> createState() => _BarberListScreenState();
}

class _BarberListScreenState extends State<BarberListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  var _loading = true;
  String? _error;
  List<SalonPreview> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool get _isFreelancer => widget.args.mode == BarberListMode.freelancers;

  Future<void> _fetch({String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final catalog = context.read<AuthController>().catalogApi;
    try {
      final List<SalonPreview> mapped;
      if (_isFreelancer) {
        final barbers = await catalog.listBarbers(q: q);
        mapped = barbers.map(SalonPreview.fromBarber).toList();
      } else {
        final shops = await catalog.listShops(q: q);
        mapped = shops.map(SalonPreview.fromShop).toList();
      }
      if (!mounted) return;
      setState(() {
        _items = mapped;
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetch(q: value.trim().isEmpty ? null : value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _isFreelancer ? 'Mobile Barbers' : 'Barber shops near you';
    final hint =
        _isFreelancer ? 'Find a mobile barber......' : 'Find barber shops......';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.page,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: context.textStyles.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: context.textStyles.bodySmall?.copyWith(
                          color: AppColors.brandPrimary,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        filled: true,
                        fillColor: AppColors.lightSurfaceVariant,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Material(
                    color: AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                    child: InkWell(
                      onTap: () => showBarberFilterSheet(context),
                      borderRadius: BorderRadius.circular(4),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.tune,
                          size: 18,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const SalonListSkeleton()
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!),
                              TextButton(
                                onPressed: () => _fetch(
                                  q: _searchController.text.trim().isEmpty
                                      ? null
                                      : _searchController.text.trim(),
                                ),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                'No results',
                                style: context.textStyles.bodyLarge,
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.page,
                                0,
                                AppSpacing.page,
                                AppSpacing.xl,
                              ),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final salon = _items[index];
                                return SalonListCard(
                                  salon: salon,
                                  expanded: _isFreelancer,
                                  onTap: () {
                                    Navigator.of(context).pushNamed(
                                      AppRoutes.providerDetail,
                                      arguments: salon.toDetailArgs(),
                                    );
                                  },
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
