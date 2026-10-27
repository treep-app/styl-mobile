import 'package:flutter/material.dart';

import '../../../core/network/api_models.dart';
import '../data/salon_filters.dart';
import 'looks_ui.dart';

class FilterResultsArgs {
  const FilterResultsArgs({
    required this.initial,
    required this.results,
    this.dateIsToday = true,
  });

  final SalonFilters initial;
  final List<AvailabilityShopDto> results;
  final bool dateIsToday;
}

/// Looksy Filter Results — distance, price, rating, type, hours.
class ResultsFilterScreen extends StatefulWidget {
  const ResultsFilterScreen({super.key, required this.args});

  final FilterResultsArgs args;

  @override
  State<ResultsFilterScreen> createState() => _ResultsFilterScreenState();
}

class _ResultsFilterScreenState extends State<ResultsFilterScreen> {
  late SalonFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.args.initial;
  }

  int get _count => _filters.apply(widget.args.results).length;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final openEnabled = widget.args.dateIsToday;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: LooksUi.toolbar,
        iconTheme: const IconThemeData(color: LooksUi.toolbar),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Filter Results',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20,
            color: LooksUi.ink,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _filters = SalonFilters.defaults),
            child: const Text(
              'Reset',
              style: TextStyle(
                color: LooksUi.purple,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SectionLabel(
            title: 'Distance',
            trailing: _filters.distanceLabel,
          ),
          SliderTheme(
            data: _sliderTheme,
            child: Slider(
              min: 1,
              max: 15,
              divisions: 14,
              value: _filters.distanceMiles.clamp(1, 15),
              onChanged: (v) =>
                  setState(() => _filters = _filters.copyWith(distanceMiles: v)),
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel(
            title: 'Price range',
            trailing: _filters.priceLabel,
          ),
          SliderTheme(
            data: _sliderTheme,
            child: Slider(
              min: 10,
              max: 50,
              divisions: 8,
              value: _filters.maxPrice.clamp(10, 50),
              onChanged: (v) =>
                  setState(() => _filters = _filters.copyWith(maxPrice: v)),
            ),
          ),
          const SizedBox(height: 22),
          const _SectionLabel(title: 'Rating'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                selected: _filters.minRating == null,
                onTap: () => setState(
                  () => _filters = _filters.copyWith(clearMinRating: true),
                ),
              ),
              for (final n in const [4.0, 4.5, 4.8])
                _FilterChip(
                  label: '${n.toStringAsFixed(1)}+',
                  selected: _filters.minRating == n,
                  onTap: () => setState(
                    () => _filters = _filters.copyWith(minRating: n),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel(title: 'Type'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                selected: _filters.type == SalonTypeFilter.any,
                onTap: () => setState(
                  () => _filters = _filters.copyWith(type: SalonTypeFilter.any),
                ),
              ),
              _FilterChip(
                label: 'Salon',
                selected: _filters.type == SalonTypeFilter.salon,
                onTap: () => setState(
                  () =>
                      _filters = _filters.copyWith(type: SalonTypeFilter.salon),
                ),
              ),
              _FilterChip(
                label: 'Mobile',
                selected: _filters.type == SalonTypeFilter.mobile,
                onTap: () => setState(
                  () =>
                      _filters = _filters.copyWith(type: SalonTypeFilter.mobile),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ToggleRow(
            label: 'Open now',
            value: openEnabled && _filters.openNow,
            enabled: openEnabled,
            onChanged: (v) =>
                setState(() => _filters = _filters.copyWith(openNow: v)),
          ),
          _ToggleRow(
            label: 'Instant booking',
            value: _filters.instantBooking,
            onChanged: (v) =>
                setState(() => _filters = _filters.copyWith(instantBooking: v)),
          ),
          _ToggleRow(
            label: 'Verified professionals only',
            value: _filters.verifiedOnly,
            onChanged: (v) =>
                setState(() => _filters = _filters.copyWith(verifiedOnly: v)),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () {
              final out = widget.args.dateIsToday
                  ? _filters
                  : _filters.copyWith(openNow: false);
              Navigator.pop(context, out);
            },
            style: FilledButton.styleFrom(
              backgroundColor: LooksUi.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(
              'Show $_count result${_count == 1 ? '' : 's'}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  SliderThemeData get _sliderTheme {
    return SliderTheme.of(context).copyWith(
      activeTrackColor: LooksUi.purple,
      inactiveTrackColor: const Color(0xFFE8E4F8),
      thumbColor: LooksUi.purple,
      overlayColor: LooksUi.purple.withValues(alpha: 0.12),
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: LooksUi.ink,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: LooksUi.muted,
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? LooksUi.purple : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? LooksUi.purple : const Color(0xFFE4E0F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : LooksUi.ink,
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: enabled ? LooksUi.ink : LooksUi.muted,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: LooksUi.purple,
          ),
        ],
      ),
    );
  }
}
