import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';

/// Figma Filter bottom sheet (#217:3856).
Future<void> showBarberFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _FilterSheet(),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  RangeValues _distance = const RangeValues(1, 10);
  String _country = 'India';
  String _area = 'Indus town';
  String _sort = 'Rating';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        boxShadow: [
          BoxShadow(
            color: Color(0x47000000),
            blurRadius: 40,
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.lg + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filter',
                  style: context.textStyles.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Country', style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: ['India', 'USA', 'UK'].map((value) {
                final selected = _country == value;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _country = value),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Area', style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: ['Indus town', 'Marine Drive', 'Downtown'].map((value) {
                final selected = _area == value;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _area = value),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Distance  ${_distance.start.round()}-${_distance.end.round()} mi',
              style: context.textStyles.titleSmall,
            ),
            RangeSlider(
              values: _distance,
              min: 1,
              max: 20,
              divisions: 19,
              activeColor: AppColors.brandPrimary,
              labels: RangeLabels(
                '${_distance.start.round()}',
                '${_distance.end.round()}',
              ),
              onChanged: (value) => setState(() => _distance = value),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Sort by', style: context.textStyles.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: ['Rating', 'Distance', 'Popular'].map((value) {
                final selected = _sort == value;
                return ChoiceChip(
                  label: Text(value),
                  selected: selected,
                  onSelected: (_) => setState(() => _sort = value),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            StylPrimaryButton(
              label: 'Apply',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
