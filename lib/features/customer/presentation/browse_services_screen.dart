import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../data/looks_catalog.dart';
import 'look_details_screen.dart';
import 'looks_ui.dart';

class BrowseServicesArgs {
  const BrowseServicesArgs({this.categoryId = 'barber'});

  final String categoryId;
}

/// Browse a category as a service list (Barbering, Fades, Tapers…).
class BrowseServicesScreen extends StatefulWidget {
  const BrowseServicesScreen({
    super.key,
    this.args = const BrowseServicesArgs(),
  });

  final BrowseServicesArgs args;

  @override
  State<BrowseServicesScreen> createState() => _BrowseServicesScreenState();
}

class _BrowseServicesScreenState extends State<BrowseServicesScreen> {
  var _tag = 'All';

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
    final title = LooksCatalog.browseTitle(widget.args.categoryId);
    final looks = auth.looksForCategory(widget.args.categoryId);
    final taxonomyTags = LooksCatalog.browseTags(widget.args.categoryId);
    final tags = [
      ...taxonomyTags,
      ...{for (final l in looks) l.tag}.where(
        (t) => t != 'All' && !taxonomyTags.contains(t),
      ),
    ];
    final filtered = _tag == 'All'
        ? looks
        : looks.where((l) => l.tag == _tag).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        iconTheme: const IconThemeData(color: LooksUi.toolbar),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: tags.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final tag = tags[i];
                final selected = tag == _tag;
                return GestureDetector(
                  onTap: () => setState(() => _tag = tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? LooksUi.purple : LooksUi.chipIdle,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : LooksUi.muted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: auth.marketplaceLoading && looks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No services in this filter yet.',
                            style: TextStyle(color: LooksUi.muted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 8, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: LooksUi.hairline,
                        ),
                        itemBuilder: (context, i) {
                          final look = filtered[i];
                          return ListTile(
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.lookDetails,
                                arguments: LookDetailsArgs(lookId: look.id),
                              );
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            leading: ClipOval(
                              child: SizedBox(
                                width: 58,
                                height: 58,
                                child: LookPhoto(url: look.imageUrl),
                              ),
                            ),
                            title: Text(
                              look.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: LooksUi.ink,
                              ),
                            ),
                            subtitle: const Text(
                              'Find salons and professionals',
                              style: TextStyle(
                                color: LooksUi.muted,
                                fontSize: 13,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: LooksUi.muted,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
