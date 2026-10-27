import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

const _accent = Color(0xFF4F6BFF);
const _ink = Color(0xFF1B2A4A);
const _muted = Color(0xFF8B93A7);
const _border = Color(0xFFE5E7EB);

class _DayHours {
  _DayHours({
    required this.weekday,
    required this.label,
    this.open = true,
  });

  final int weekday;
  final String label;
  bool open;
  String start = '09:00';
  String end = '19:00';
}

class _SpecialHours {
  _SpecialHours({
    required this.label,
    required this.start,
    required this.end,
    this.closed = false,
  });

  String label;
  String start;
  String end;
  bool closed;
}

/// Owner onboarding — set salon opening hours (matches product UI).
class SalonOpeningHoursScreen extends StatefulWidget {
  const SalonOpeningHoursScreen({
    super.key,
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;

  @override
  State<SalonOpeningHoursScreen> createState() =>
      _SalonOpeningHoursScreenState();
}

class _SalonOpeningHoursScreenState extends State<SalonOpeningHoursScreen> {
  static const _times = [
    '08:00',
    '08:30',
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '12:00',
    '12:30',
    '13:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
    '18:30',
    '19:00',
    '19:30',
    '20:00',
    '20:30',
    '21:00',
  ];

  late final List<_DayHours> _days;
  final _special = <_SpecialHours>[];
  var _saving = false;
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _shopId = widget.shopId;
    _days = [
      _DayHours(weekday: 1, label: 'Monday'),
      _DayHours(weekday: 2, label: 'Tuesday'),
      _DayHours(weekday: 3, label: 'Wednesday'),
      _DayHours(weekday: 4, label: 'Thursday'),
      _DayHours(weekday: 5, label: 'Friday'),
      _DayHours(weekday: 6, label: 'Saturday'),
      _DayHours(weekday: 0, label: 'Sunday', open: false),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    try {
      final auth = context.read<AuthController>();
      var shopId = _shopId;

      // Prefer the professional's own hours so staff can edit independently.
      final personal = await auth.catalogApi.listMyWorkingHours();
      if (!mounted) return;
      if (personal.isNotEmpty) {
        for (final day in _days) {
          final match =
              personal.where((h) => h.weekday == day.weekday).toList();
          if (match.isEmpty) {
            day.open = false;
          } else {
            day.open = true;
            day.start = match.first.startTime.substring(0, 5);
            day.end = match.first.endTime.substring(0, 5);
          }
        }
        if (shopId == null) {
          final mine = await auth.catalogApi.listMyShops();
          shopId = mine.where((s) => s.isOwner == true).firstOrNull?.id ??
              mine.firstOrNull?.id;
        }
        setState(() => _shopId = shopId);
        return;
      }

      if (shopId == null) {
        final mine = await auth.catalogApi.listMyShops();
        shopId = mine.where((s) => s.isOwner == true).firstOrNull?.id ??
            mine.firstOrNull?.id;
      }
      if (shopId == null || !mounted) return;
      final shop = await auth.catalogApi.getShop(shopId);
      if (!mounted) return;
      if (shop.workingHours.isNotEmpty) {
        for (final day in _days) {
          final match = shop.workingHours
              .where((h) => h.weekday == day.weekday)
              .toList();
          if (match.isEmpty) {
            day.open = false;
          } else {
            day.open = true;
            day.start = match.first.startTime.substring(0, 5);
            day.end = match.first.endTime.substring(0, 5);
          }
        }
      }
      setState(() => _shopId = shopId);
    } catch (_) {}
  }

  String _format12h(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    var hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:${minute.padLeft(2, '0')} $period';
  }

  String _rangeLabel(String start, String end) =>
      '${_format12h(start)} – ${_format12h(end)}';

  Future<void> _editDayRange(_DayHours day) async {
    if (!day.open) return;
    final result = await _pickTimeRange(
      title: day.label,
      start: day.start,
      end: day.end,
    );
    if (result == null || !mounted) return;
    setState(() {
      day.start = result.$1;
      day.end = result.$2;
    });
  }

  Future<(String, String)?> _pickTimeRange({
    required String title,
    required String start,
    required String end,
  }) async {
    var draftStart = _times.contains(start) ? start : '09:00';
    var draftEnd = _times.contains(end) ? end : '19:00';
    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.paddingOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SheetTimeDropdown(
                          label: 'Opens',
                          value: draftStart,
                          items: _times,
                          format: _format12h,
                          onChanged: (v) {
                            if (v != null) setModal(() => draftStart = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SheetTimeDropdown(
                          label: 'Closes',
                          value: draftEnd,
                          items: _times,
                          format: _format12h,
                          onChanged: (v) {
                            if (v != null) setModal(() => draftEnd = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(ctx).pop((draftStart, draftEnd)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addSpecialHours() async {
    final result = await showModalBottomSheet<_SpecialHours>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _AddSpecialHoursSheet(
        times: _times,
        format12h: _format12h,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _special.add(result));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final store = SessionStore();
    final auth = context.read<AuthController>();
    try {
      final openDays = _days.where((d) => d.open).toList();
      if (openDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Open at least one day.')),
        );
        setState(() => _saving = false);
        return;
      }
      await auth.catalogApi.replaceWorkingHours([
        for (final d in openDays)
          {
            'weekday': d.weekday,
            'startTime': d.start,
            'endTime': d.end,
            if (_shopId != null) 'shopId': _shopId,
          },
      ]);

      if (widget.fromOnboarding) {
        await store.setProviderSetupStage('team');
        await store.setProviderSetupShopId(_shopId);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.providerSalonTeam,
          (route) => false,
          arguments: SalonSetupArgs(
            shopId: _shopId,
            fromOnboarding: true,
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).maybePop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onBack() async {
    if (widget.fromOnboarding) {
      await SessionStore().setProviderSetupStage('services');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.providerServices,
        (route) => false,
        arguments: ProviderServicesArgs(
          shopId: _shopId,
          fromOnboarding: true,
        ),
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _onBack,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Opening Hours',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _saving
                            ? _accent.withValues(alpha: 0.4)
                            : _accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Text(
                    'Set your regular opening hours.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _muted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final day in _days) ...[
                    _DayRow(
                      label: day.label,
                      rangeText: day.open
                          ? _rangeLabel(day.start, day.end)
                          : 'Closed',
                      open: day.open,
                      onToggle: (v) => setState(() => day.open = v),
                      onTapRange: () => _editDayRange(day),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Special hours',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Set your salon's holidays or special opening hours.",
                    style: TextStyle(
                      fontSize: 14,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final item in _special) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              item.closed
                                  ? 'Closed'
                                  : _rangeLabel(item.start, item.end),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _ink,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _special.remove(item)),
                            icon: const Icon(Icons.close, size: 18),
                            color: _muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                  Material(
                    color: const Color(0xFFEEF0FF),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _addSpecialHours,
                      borderRadius: BorderRadius.circular(14),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: _accent, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Add special hours',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddSpecialHoursSheet extends StatefulWidget {
  const _AddSpecialHoursSheet({
    required this.times,
    required this.format12h,
  });

  final List<String> times;
  final String Function(String) format12h;

  @override
  State<_AddSpecialHoursSheet> createState() => _AddSpecialHoursSheetState();
}

class _AddSpecialHoursSheetState extends State<_AddSpecialHoursSheet> {
  late final TextEditingController _labelController;
  var _start = '09:00';
  var _end = '19:00';
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    Navigator.of(context).pop(
      _SpecialHours(
        label: label,
        start: _start,
        end: _end,
        closed: _closed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + safeBottom + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add special hours',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _labelController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'e.g. Christmas Day, Bank Holiday',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Closed all day',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              value: _closed,
              activeThumbColor: _accent,
              activeTrackColor: _accent.withValues(alpha: 0.45),
              onChanged: (v) => setState(() => _closed = v),
            ),
            if (!_closed) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _SheetTimeDropdown(
                      label: 'Opens',
                      value: _start,
                      items: widget.times,
                      format: widget.format12h,
                      onChanged: (v) {
                        if (v != null) setState(() => _start = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SheetTimeDropdown(
                      label: 'Closes',
                      value: _end,
                      items: widget.times,
                      format: widget.format12h,
                      onChanged: (v) {
                        if (v != null) setState(() => _end = v);
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.rangeText,
    required this.open,
    required this.onToggle,
    required this.onTapRange,
  });

  final String label;
  final String rangeText;
  final bool open;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapRange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.brandPrimary,
            ),
          ),
        ),
        Expanded(
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: open ? onTapRange : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  rangeText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: open ? _ink : _muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Switch.adaptive(
          value: open,
          activeThumbColor: Colors.white,
          activeTrackColor: _accent,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFE5E7EB),
          onChanged: onToggle,
        ),
      ],
    );
  }
}

class _SheetTimeDropdown extends StatelessWidget {
  const _SheetTimeDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.format,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final String Function(String) format;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: safe,
          items: items
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(format(t)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
      ],
    );
  }
}
