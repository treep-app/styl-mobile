import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/post_auth_navigation.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';

/// Centered 4-digit OTP — SMS autofill + auto-verify + wrong-code alert.
/// Layout inspired by modern verification UIs (e.g. Dribbble OTP flows).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const _length = 4;

  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  var _submitting = false;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _maskedPhone {
    final raw = widget.args.phoneNumber.replaceAll(RegExp(r'\s+'), '');
    if (raw.length <= 4) return raw;
    final tail = raw.substring(raw.length - 4);
    final head = raw.substring(0, raw.length - 4);
    final maskedHead = head.replaceAll(RegExp(r'\d'), '•');
    return '$maskedHead$tail';
  }

  Future<void> _showWrongCodeAlert(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Incorrect code',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message.isNotEmpty
                ? message
                : 'The OTP you entered is incorrect. Please try again.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.lightOnSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Try again',
                style: TextStyle(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _verify([String? code]) async {
    final pin = (code ?? _pinController.text).trim();
    if (pin.length != _length || _submitting) return;

    setState(() => _submitting = true);

    final auth = context.read<AuthController>();
    final role = widget.args.isServiceProvider ? 'BARBER' : 'CLIENT';

    try {
      await auth.verifyOtp(
        phone: widget.args.phoneNumber,
        code: pin,
        fullName: widget.args.fromSignUp ? widget.args.fullName : null,
        password: widget.args.fromSignUp ? widget.args.password : null,
        role: role,
      );

      if (widget.args.isServiceProvider &&
          widget.args.fromSignUp &&
          widget.args.providerSignup != null) {
        try {
          await _completeProviderOnboarding(
            auth,
            widget.args.providerSignup!,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is ApiException
                    ? 'Signed in. Finish salon setup in Manage salon. ${e.message}'
                    : 'Signed in. Finish salon setup in Manage salon.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      // Phone sign-up continues to role (Customer vs Service Professional).
      if (widget.args.fromSignUp && !widget.args.isServiceProvider) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.chooseRole);
        return;
      }

      final dest = await resolvePostAuthDestination(auth);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        dest.route,
        (route) => false,
        arguments: dest.arguments,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _pinController.clear();
      HapticFeedback.heavyImpact();
      await _showWrongCodeAlert(e.message);
      if (mounted) _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _pinController.clear();
      HapticFeedback.heavyImpact();
      await _showWrongCodeAlert(
        'The OTP you entered is incorrect. Please try again.',
      );
      if (mounted) _focusNode.requestFocus();
    }
  }

  Future<void> _completeProviderOnboarding(
    AuthController auth,
    ProviderSignupDraft draft,
  ) async {
    String? shopId = draft.linkShopId;

    if (draft.createSalon) {
      var website = draft.website?.trim();
      if (website != null &&
          website.isNotEmpty &&
          !website.startsWith('http')) {
        website = 'https://$website';
      }
      final shop = await auth.catalogApi.createShop({
        'name': draft.salonName ?? 'My Salon',
        'addressLine': draft.addressLine ?? 'Address TBD',
        if (draft.area != null) 'area': draft.area,
        if (draft.district != null) 'district': draft.district,
        if (draft.pincode != null) 'pincode': draft.pincode,
        if (draft.description != null) 'description': draft.description,
        if (website != null && website.isNotEmpty) 'website': website,
      });
      shopId = shop.id;
    } else if (draft.linkShopId != null) {
      await auth.catalogApi.linkShop(draft.linkShopId!);
      shopId = draft.linkShopId;
    }

    if (shopId != null && draft.createSalon) {
      for (final service in draft.services) {
        if (service.name.trim().isEmpty) continue;
        await auth.catalogApi.createService(
          shopId,
          name: service.name.trim(),
          priceAmount: service.priceAmount,
        );
      }
    }

    await auth.catalogApi.replaceWorkingHours([
      for (var d = 1; d <= 6; d++)
        {
          'weekday': d,
          'startTime': '10:00',
          'endTime': '20:00',
          'shopId': ?shopId,
        },
    ]);
  }

  Future<void> _resend() async {
    if (_submitting) return;
    final auth = context.read<AuthController>();
    final role = widget.args.isServiceProvider ? 'BARBER' : 'CLIENT';
    try {
      final result = await auth.sendOtp(
        phone: widget.args.phoneNumber,
        role: role,
      );
      if (!mounted) return;
      _pinController.clear();
      _focusNode.requestFocus();
      final msg = result.devCode != null
          ? 'OTP resent (dev: ${result.devCode})'
          : 'A new code was sent to your phone.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pinSize = ((screenWidth - 48 - 36) / 4).clamp(56.0, 68.0);

    final defaultPinTheme = PinTheme(
      width: pinSize,
      height: pinSize,
      textStyle: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.brandPrimary,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandPrimary, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Spacer(),
                  Image.asset(
                    AppAssets.logo,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + bottomInset),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FB),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.sms_outlined,
                        size: 34,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Phone verification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.lightOnSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Enter the 4-digit code we sent to\n',
                          ),
                          TextSpan(
                            text: _maskedPhone,
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    AutofillGroup(
                      child: Pinput(
                        length: _length,
                        controller: _pinController,
                        focusNode: _focusNode,
                        enabled: !_submitting,
                        autofocus: true,
                        mainAxisAlignment: MainAxisAlignment.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofillHints: const [AutofillHints.oneTimeCode],
                        hapticFeedbackType: HapticFeedbackType.lightImpact,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: focusedPinTheme,
                        separatorBuilder: (_) => const SizedBox(width: 12),
                        onCompleted: (pin) => _verify(pin),
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextButton(
                      onPressed: _submitting ? null : _resend,
                      child: const Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                          children: [
                            TextSpan(text: "Didn't get a code? "),
                            TextSpan(
                              text: 'Resend',
                              style: TextStyle(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StylPrimaryButton(
                      label: _submitting ? 'Verifying…' : 'Verify',
                      isLoading: _submitting,
                      onPressed:
                          !_submitting && _pinController.text.length == _length
                              ? () => _verify()
                              : null,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Code fills automatically from SMS when available.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
