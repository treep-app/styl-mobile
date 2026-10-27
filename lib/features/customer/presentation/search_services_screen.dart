import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/constants/salon_service_catalog.dart';
import '../../../core/routing/app_routes.dart';
import '../data/looks_catalog.dart';
import 'look_details_screen.dart';
import 'looks_ui.dart';

/// Customer “Search services” — long categorized multi-select list.
class SearchServicesScreen extends StatefulWidget {
  const SearchServicesScreen({super.key});

  @override
  State<SearchServicesScreen> createState() => _SearchServicesScreenState();
}

class _SearchServicesScreenState extends State<SearchServicesScreen> {
  final _selected = <String>{};
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().loadMarketplace();
    });
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Map<String, List<String>> get _sections {
    final q = _query.text.trim().toLowerCase();
    final all = SalonServiceCatalog.searchSections;
    if (q.isEmpty) return all;
    final filtered = <String, List<String>>{};
    for (final entry in all.entries) {
      final matches = entry.value
          .where((name) => name.toLowerCase().contains(q))
          .toList();
      if (matches.isNotEmpty || entry.key.toLowerCase().contains(q)) {
        filtered[entry.key] =
            matches.isNotEmpty ? matches : entry.value;
      }
    }
    return filtered;
  }

  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  List<StyleLook> _matchingLooks(AuthController auth) {
    if (_selected.isEmpty) return const [];
    final selected = _selected.map((s) => s.toLowerCase()).toSet();
    return auth.marketplaceLooks.where((look) {
      final n = look.name.toLowerCase();
      return selected.any((s) => n.contains(s) || s.contains(n));
    }).toList();
  }

  void _showResults() {
    final auth = context.read<AuthController>();
    final looks = _matchingLooks(auth);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ServiceSearchResultsScreen(
          selected: _selected.toList()..sort(),
          looks: looks,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search services',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                hintText: 'Search fade, acrylic, manicure…',
                filled: true,
                fillColor: LooksUi.searchFill,
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selected.length} selected — tap again to deselect',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: LooksUi.muted,
                  ),
                ),
              ),
            ),
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Text(
                      'No matching services',
                      style: TextStyle(color: LooksUi.muted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: sections.length,
                    itemBuilder: (context, i) {
                      final category = sections.keys.elementAt(i);
                      final names = sections[category]!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                                color: LooksUi.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final name in names)
                                  FilterChip(
                                    label: Text(name),
                                    selected: _selected.contains(name),
                                    onSelected: (_) => _toggle(name),
                                    selectedColor: LooksUi.purple,
                                    backgroundColor: LooksUi.chipIdle,
                                    checkmarkColor: Colors.white,
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: _selected.contains(name)
                                          ? Colors.white
                                          : LooksUi.ink,
                                    ),
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottom * 0.15),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : _showResults,
                  style: FilledButton.styleFrom(
                    backgroundColor: LooksUi.purple,
                    disabledBackgroundColor: LooksUi.chipIdle,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    _selected.isEmpty
                        ? 'Select one or more services'
                        : 'Show results (${_selected.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSearchResultsScreen extends StatelessWidget {
  const _ServiceSearchResultsScreen({
    required this.selected,
    required this.looks,
  });

  final List<String> selected;
  final List<StyleLook> looks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          looks.isEmpty
              ? 'No matches yet'
              : '${looks.length} style${looks.length == 1 ? '' : 's'}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: looks.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size: 42,
                    color: LooksUi.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No salons list ${selected.join(', ')} yet. Try other services, or check back soon.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: LooksUi.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 24),
              itemCount: looks.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: LooksUi.hairline),
              itemBuilder: (context, i) {
                final look = looks[i];
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
                  subtitle: Text(
                    '${look.priceLabel} · ${look.prosNearby} nearby',
                    style: const TextStyle(
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
    );
  }
}
