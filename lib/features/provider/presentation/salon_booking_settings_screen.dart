import 'package:flutter/material.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

const _accent = Color(0xFF4F6BFF);
const _muted = Color(0xFF8B93A7);
const _border = Color(0xFFE5E7EB);

/// Owner onboarding — booking preferences before entering the salon hub.
class SalonBookingSettingsScreen extends StatefulWidget {
  const SalonBookingSettingsScreen({
    super.key,
    this.shopId,
    this.fromOnboarding = false,
  });

  final String? shopId;
  final bool fromOnboarding;

  @override
  State<SalonBookingSettingsScreen> createState() =>
      _SalonBookingSettingsScreenState();
}

class _SalonBookingSettingsScreenState
    extends State<SalonBookingSettingsScreen> {
  static const _minNoticeOptions = [
    'Same day',
    '1 hour',
    '2 hours',
    '4 hours',
    '12 hours',
    '24 hours',
  ];
  static const _maxAdvanceOptions = [
    '7 days',
    '14 days',
    '30 days',
    '60 days',
    '90 days',
  ];
  static const _cancelOptions = [
    '2 hours',
    '12 hours',
    '24 hours',
    '48 hours',
    'No cancellations',
  ];
  static const _depositOptions = [
    'No deposit',
    '£5',
    '£10',
    '£20',
    '20%',
  ];

  var _minNotice = '2 hours';
  var _maxAdvance = '60 days';
  var _cancelPolicy = '24 hours';
  var _deposit = 'No deposit';
  var _saving = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
  }

  Future<void> _hydrate() async {
    final store = SessionStore();
    final minNotice = await store.readBookingMinNotice();
    final maxAdvance = await store.readBookingMaxAdvance();
    final cancel = await store.readBookingCancelPolicy();
    final deposit = await store.readBookingDeposit();
    if (!mounted) return;
    setState(() {
      _minNotice = _minNoticeOptions.contains(minNotice) ? minNotice : '2 hours';
      _maxAdvance =
          _maxAdvanceOptions.contains(maxAdvance) ? maxAdvance : '60 days';
      _cancelPolicy =
          _cancelOptions.contains(cancel) ? cancel : '24 hours';
      _deposit = _depositOptions.contains(deposit) ? deposit : 'No deposit';
      _loading = false;
    });
  }

  String get _cancelHint {
    if (_cancelPolicy == 'No cancellations') {
      return 'Customers cannot cancel bookings in the app.';
    }
    return 'Customers can cancel up to $_cancelPolicy before.';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final store = SessionStore();
    try {
      await store.setBookingMinNotice(_minNotice);
      await store.setBookingMaxAdvance(_maxAdvance);
      await store.setBookingCancelPolicy(_cancelPolicy);
      await store.setBookingDeposit(_deposit);
      // Keep legacy flags in sync with notice / advance choices.
      await store.setBookingSameDayAllowed(
        _minNotice == 'Same day' || _minNotice == '1 hour' || _minNotice == '2 hours',
      );
      await store.setBookingInstantConfirm(true);

      if (widget.fromOnboarding) {
        await store.setOwnerOnboardingComplete(true);
        await store.clearProviderSetup();
        await store.setPreferCustomerView(false);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.providerSalonDashboard,
          (route) => false,
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
      await SessionStore().setProviderSetupStage('team');
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.providerSalonTeam,
        (route) => false,
        arguments: SalonSetupArgs(
          shopId: widget.shopId,
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
                      'Booking Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: (_saving || _loading) ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (_saving || _loading)
                            ? _accent.withValues(alpha: 0.4)
                            : _accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        const Text(
                          'Set how bookings work at your salon.',
                          style: TextStyle(
                            fontSize: 14,
                            color: _muted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SettingDropdown(
                          label: 'Minimum booking notice',
                          value: _minNotice,
                          options: _minNoticeOptions,
                          hint:
                              'Minimum time before an appointment can be booked.',
                          onChanged: (v) {
                            if (v != null) setState(() => _minNotice = v);
                          },
                        ),
                        const SizedBox(height: 22),
                        _SettingDropdown(
                          label: 'Maximum advance booking',
                          value: _maxAdvance,
                          options: _maxAdvanceOptions,
                          hint: 'How far in advance customers can book.',
                          onChanged: (v) {
                            if (v != null) setState(() => _maxAdvance = v);
                          },
                        ),
                        const SizedBox(height: 22),
                        _SettingDropdown(
                          label: 'Cancellation policy',
                          value: _cancelPolicy,
                          options: _cancelOptions,
                          hint: _cancelHint,
                          onChanged: (v) {
                            if (v != null) setState(() => _cancelPolicy = v);
                          },
                        ),
                        const SizedBox(height: 22),
                        _SettingDropdown(
                          label: 'Default deposit (optional)',
                          value: _deposit,
                          options: _depositOptions,
                          hint: 'You can override this per service later.',
                          onChanged: (v) {
                            if (v != null) setState(() => _deposit = v);
                          },
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

class _SettingDropdown extends StatelessWidget {
  const _SettingDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.hint,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final safe = options.contains(value) ? value : options.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: safe,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF9CA3AF),
          ),
          items: options
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(
                    o,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: _muted,
          ),
        ),
      ],
    );
  }
}
