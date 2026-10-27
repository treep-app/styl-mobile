import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../data/looks_catalog.dart';
import 'available_today_screen.dart';
import 'find_professionals_screen.dart';
import 'looks_ui.dart';

class LookDetailsArgs {
  const LookDetailsArgs({required this.lookId});

  final String lookId;
}

class LookDetailsScreen extends StatefulWidget {
  const LookDetailsScreen({super.key, required this.args});

  final LookDetailsArgs args;

  @override
  State<LookDetailsScreen> createState() => _LookDetailsScreenState();
}

class _LookDetailsScreenState extends State<LookDetailsScreen> {
  var _saved = false;

  @override
  void initState() {
    super.initState();
    SessionStore().isLookSaved(widget.args.lookId).then((v) {
      if (mounted) setState(() => _saved = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().loadMarketplace();
    });
  }

  Future<void> _toggleSave() async {
    final next = !_saved;
    setState(() => _saved = next);
    await SessionStore().setLookSaved(widget.args.lookId, next);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final look = auth.lookById(widget.args.lookId);
    final similar = look == null
        ? const <StyleLook>[]
        : auth.marketplaceLooks
            .where((l) => l.categoryId == look.categoryId && l.id != look.id)
            .take(6)
            .toList();
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (look == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: auth.marketplaceLoading
              ? const CircularProgressIndicator()
              : const Text('This look is no longer available.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 420,
                  pinned: true,
                  backgroundColor: Colors.white,
                  foregroundColor: LooksUi.toolbar,
                  iconTheme: const IconThemeData(color: LooksUi.toolbar),
                  actionsIconTheme: const IconThemeData(color: LooksUi.toolbar),
                  actions: [
                    IconButton(
                      onPressed: _toggleSave,
                      icon: Icon(
                        _saved ? Icons.favorite_rounded : Icons.favorite_border,
                        color: _saved ? LooksUi.purple : LooksUi.toolbar,
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        LookPhoto(url: look.imageUrl),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.center,
                              colors: [
                                Color(0x66000000),
                                Color(0x00000000),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          look.name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From ${look.priceLabel} · ${look.prosNearby} professional${look.prosNearby == 1 ? '' : 's'} nearby',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          look.description,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                        if (similar.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Similar styles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 92,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: similar.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final s = similar[i];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pushReplacementNamed(
                                      AppRoutes.lookDetails,
                                      arguments: LookDetailsArgs(lookId: s.id),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: LookPhoto(
                                      url: s.imageUrl,
                                      width: 92,
                                      height: 92,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.findProfessionals,
                          arguments: FindProfessionalsArgs(lookId: look.id),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Find professionals near me',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.availableToday,
                          arguments: AvailableTodayArgs(
                            lookId: look.id,
                            lookName: look.name,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        side: const BorderSide(color: AppColors.brandPrimary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'See available times',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
