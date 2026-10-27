import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../customer/presentation/looks_ui.dart';

/// Shop portfolio photos from the linked salon.
class ProviderPortfolioScreen extends StatefulWidget {
  const ProviderPortfolioScreen({super.key});

  @override
  State<ProviderPortfolioScreen> createState() =>
      _ProviderPortfolioScreenState();
}

class _ProviderPortfolioScreenState extends State<ProviderPortfolioScreen> {
  var _loading = true;
  String? _error;
  ShopDto? _shop;

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
      if (shop != null) {
        shop = await auth.catalogApi.getShop(shop.id);
      }
      if (!mounted) return;
      setState(() {
        _shop = shop;
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
    final urls = _shop?.imageUrls ?? const <String>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: LooksUi.ink,
        title: const Text(
          'Portfolio',
          style: TextStyle(fontWeight: FontWeight.w800, color: LooksUi.ink),
        ),
        actions: [
          if (_shop != null)
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed(
                AppRoutes.providerManageSalon,
                arguments: _shop!.id,
              ),
              child: const Text('Edit'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LooksUi.purple))
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
                  child: urls.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(28),
                          children: [
                            const SizedBox(height: 48),
                            const Icon(
                              Icons.photo_library_outlined,
                              size: 44,
                              color: LooksUi.navGray,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No portfolio photos yet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: LooksUi.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add salon photos so clients can see your work.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: LooksUi.muted),
                            ),
                            const SizedBox(height: 20),
                            if (_shop != null)
                              Center(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: LooksUi.purple,
                                  ),
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(
                                    AppRoutes.providerManageSalon,
                                    arguments: _shop!.id,
                                  ),
                                  child: const Text('Add photos'),
                                ),
                              ),
                          ],
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: urls.length,
                          itemBuilder: (context, i) {
                            return Hero(
                              tag: urls[i],
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Material(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => _PhotoViewer(
                                            urls: urls,
                                            initialIndex: i,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Image.network(
                                      urls[i],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const ColoredBox(
                                        color: LooksUi.chipIdle,
                                        child: Icon(
                                          Icons.broken_image_outlined,
                                          color: LooksUi.muted,
                                        ),
                                      ),
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

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: urls.length,
        itemBuilder: (context, i) {
          return InteractiveViewer(
            child: Center(
              child: Hero(
                tag: urls[i],
                child: Image.network(urls[i], fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}
