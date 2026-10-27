import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../data/looks_catalog.dart';
import 'browse_services_screen.dart';
import 'look_details_screen.dart';

/// Browse all looks from the live catalog.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().loadMarketplace();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final looks = auth.marketplaceLooks.where((l) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return l.name.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q);
    }).toList();
    final categories = auth.marketplaceCategories;

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => auth.loadMarketplace(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                'Explore',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Browse looks and find someone nearby who can do them.',
                style: TextStyle(color: AppColors.lightOnSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search looks',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (auth.marketplaceLoading && looks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (looks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: Text(
                    'No looks yet. They appear when salons add services.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.lightOnSurfaceVariant),
                  ),
                )
              else ...[
                if (categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = categories[i];
                        return ActionChip(
                          label: Text(c.label),
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.browseServices,
                              arguments: BrowseServicesArgs(categoryId: c.id),
                            );
                          },
                          backgroundColor: const Color(0xFFF3F7FB),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: looks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, i) {
                    final look = looks[i];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.lookDetails,
                          arguments: LookDetailsArgs(lookId: look.id),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: LookPhoto(
                                url: look.imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            look.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          Text(
                            'From ${look.priceLabel}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.lightOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
