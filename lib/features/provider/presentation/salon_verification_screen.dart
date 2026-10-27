import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../widgets/styl_primary_button.dart';
import '../../customer/data/catalog_api.dart';

const _accent = Color(0xFF4F6BFF);
const _ink = Color(0xFF003E6F);
const _muted = Color(0xFF8B93A7);
const _success = Color(0xFF1B8A5A);

/// Salon owner — request / view STYL Verified status.
class SalonVerificationScreen extends StatefulWidget {
  const SalonVerificationScreen({super.key, this.shopId});

  final String? shopId;

  @override
  State<SalonVerificationScreen> createState() =>
      _SalonVerificationScreenState();
}

class _SalonVerificationScreenState extends State<SalonVerificationScreen> {
  SalonVerificationDto? _data;
  var _loading = true;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final shopId = widget.shopId;
    if (shopId == null || shopId.isEmpty) {
      setState(() {
        _error = 'No salon selected';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context
          .read<AuthController>()
          .catalogApi
          .getShopVerification(shopId);
      if (!mounted) return;
      setState(() {
        _data = data;
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

  Future<void> _request() async {
    final shopId = widget.shopId;
    if (shopId == null) return;
    setState(() => _submitting = true);
    try {
      final data = await context
          .read<AuthController>()
          .catalogApi
          .requestShopVerification(shopId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _submitting = false;
      });
      final msg = data.message ??
          (data.isVerified
              ? 'Your salon is now STYL Verified.'
              : 'Verification request submitted.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = _data?.shop;
    final verified = shop?.isVerified == true;
    final pending = shop?.verificationStatus == 'PENDING';
    final checklist = _data?.checklist ?? const [];
    final ready = checklist.isNotEmpty && checklist.every((c) => c.met);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: _muted),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                          children: [
                            _StatusHero(
                              verified: verified,
                              pending: pending,
                              salonName: shop?.name ?? 'Your salon',
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'What customers see',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              verified
                                  ? 'A verified badge appears next to your salon name across STYL — home, search, and your profile.'
                                  : 'Once verified, a blue checkmark appears next to your salon name so customers know you’re a trusted STYL Pro salon.',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Readiness checklist',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final item in checklist)
                              _CheckRow(item: item),
                            if (!verified) ...[
                              const SizedBox(height: 24),
                              StylPrimaryButton(
                                label: ready
                                    ? 'Get STYL Verified'
                                    : pending
                                        ? 'Update request'
                                        : 'Submit for verification',
                                onPressed: _submitting ? null : _request,
                                isLoading: _submitting,
                              ),
                              if (!ready) ...[
                                const SizedBox(height: 10),
                                const Text(
                                  'Complete every item above to unlock instant verification.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _muted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({
    required this.verified,
    required this.pending,
    required this.salonName,
  });

  final bool verified;
  final bool pending;
  final String salonName;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String title;
    final String subtitle;

    if (verified) {
      bg = const Color(0xFFE8F7EF);
      fg = _success;
      icon = Icons.verified_rounded;
      title = 'STYL Verified';
      subtitle = '$salonName shows a verified badge to customers.';
    } else if (pending) {
      bg = const Color(0xFFFFF6E5);
      fg = const Color(0xFFB7791F);
      icon = Icons.hourglass_top_rounded;
      title = 'Pending review';
      subtitle = 'Finish the checklist to unlock instant verification.';
    } else {
      bg = const Color(0xFFEEF0FF);
      fg = _accent;
      icon = Icons.verified_outlined;
      title = 'Not verified yet';
      subtitle = 'Get the STYL Verified badge customers look for.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: _ink,
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

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.item});

  final SalonVerificationChecklistItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            item.met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 22,
            color: item.met ? _success : _muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: item.met ? _ink : _muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
