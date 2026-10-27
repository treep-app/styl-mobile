import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../data/catalog_api.dart';
import 'looks_ui.dart';

class LocationSearchArgs {
  const LocationSearchArgs({this.currentLocation = ''});

  final String currentLocation;
}

/// “Where are you looking?” — search by town, area or postcode.
class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({
    super.key,
    this.args = const LocationSearchArgs(),
  });

  final LocationSearchArgs args;

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final _search = TextEditingController();
  final _store = SessionStore();
  var _query = '';
  String? _selected;
  List<String> _recents = const [];
  List<CatalogArea> _popular = const [];

  @override
  void initState() {
    super.initState();
    _selected = widget.args.currentLocation.isEmpty
        ? null
        : widget.args.currentLocation;
    if (_selected != null) _search.text = _selected!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final recents = await _store.readRecentLocations();
    CatalogAreas? remote;
    try {
      remote = await auth.catalogApi.listAreas();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recents = recents;
      _popular = remote?.popularAreas.isNotEmpty == true
          ? remote!.popularAreas
          : auth.popularAreas;
    });
  }

  void _choose(String label) {
    setState(() {
      _selected = label;
      _search.text = label;
      _query = label;
    });
  }

  void _confirm([String? label]) {
    final value = (label ?? _selected ?? _search.text).trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final recents = _recents.where((e) {
      if (q.isEmpty) return true;
      return e.toLowerCase().contains(q);
    }).toList();
    final popular = _popular.where((e) {
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q);
    }).toList();

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
        title: const Text(
          'Where are you looking?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18,
            color: LooksUi.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() {
                    _query = v;
                    _selected = v.trim().isEmpty ? _selected : v.trim();
                  }),
                  onSubmitted: (v) => _confirm(v),
                  decoration: InputDecoration(
                    hintText: 'Town, area or postcode',
                    prefixIcon: const Icon(Icons.search_rounded, color: LooksUi.muted),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _query = '';
                                _selected = null;
                              });
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: LooksUi.searchFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _confirm('Current location'),
                  icon: const Icon(Icons.near_me_rounded, color: LooksUi.purple),
                  label: const Text(
                    'Use my current location',
                    style: TextStyle(
                      color: LooksUi.purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recent locations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 4),
                for (final item in recents)
                  _LocationTile(
                    label: item,
                    selected: _selected == item,
                    onTap: () => _choose(item),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Popular areas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: LooksUi.ink,
                  ),
                ),
                const SizedBox(height: 4),
                for (final item in popular)
                  _LocationTile(
                    label: item.name,
                    selected: _selected == item.name,
                    onTap: () => _choose(item.name),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _selected == null && _search.text.trim().isEmpty
                      ? null
                      : () => _confirm(),
                  style: FilledButton.styleFrom(
                    backgroundColor: LooksUi.purple,
                    disabledBackgroundColor: LooksUi.chipIdle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Search in this area',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.schedule_rounded,
        color: selected ? LooksUi.purple : LooksUi.muted,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: LooksUi.ink,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: LooksUi.purple)
          : null,
    );
  }
}
