import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../data/looks_catalog.dart';
import 'look_details_screen.dart';

class ChooseLookArgs {
  const ChooseLookArgs({required this.categoryId, this.query});

  final String categoryId;
  final String? query;
}

/// Style grid for a category — looks from `/catalog`.
class ChooseLookScreen extends StatefulWidget {
  const ChooseLookScreen({super.key, required this.args});

  final ChooseLookArgs args;

  @override
  State<ChooseLookScreen> createState() => _ChooseLookScreenState();
}

class _ChooseLookScreenState extends State<ChooseLookScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().loadMarketplace();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final category = auth.categoryById(widget.args.categoryId);
    final looks = auth.looksForCategory(
      widget.args.categoryId,
      query: widget.args.query,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.brandPrimary,
        elevation: 0,
        title: Text(
          category.label,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1633),
          ),
        ),
      ),
      body: auth.marketplaceLoading && looks.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : looks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No services in this category yet. They’ll show here when salons add them.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: looks.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, i) {
                    final look = looks[i];
                    return _LookTile(
                      look: look,
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.lookDetails,
                          arguments: LookDetailsArgs(lookId: look.id),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _LookTile extends StatelessWidget {
  const _LookTile({required this.look, required this.onTap});

  final StyleLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.brandPrimary,
            ),
          ),
          Text(
            '${look.prosNearby} nearby · from ${look.priceLabel}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
