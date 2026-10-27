import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/post_auth_navigation.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../widgets/phone_number_field.dart';
import '../../../widgets/styl_primary_button.dart';

/// Phone + password login — no OTP. Shared by customer and provider.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.args = const LoginArgs(),
  });

  final LoginArgs args;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFieldKey = GlobalKey<PhoneNumberFieldState>();
  var _busy = false;
  var _obscurePassword = true;
  String? _error;

  bool get _isProvider => widget.args.isServiceProvider;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    setState(() => _error = null);

    if (phone.length < 7) {
      setState(() => _error = 'Enter a valid mobile number.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    final fullNumber = _phoneFieldKey.currentState?.fullNumber ??
        composeE164(dialCode: '+44', national: phone, isoCountry: 'GB');

    setState(() => _busy = true);
    try {
      final auth = context.read<AuthController>();
      await auth.login(
        phone: fullNumber,
        password: password,
      );
      if (!mounted) return;
      final dest = await resolvePostAuthDestination(auth);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        dest.route,
        (route) => false,
        arguments: dest.arguments,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _error = 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goSignUp() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.customerSignUp);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: AppColors.brandPrimary,
                    )
                  else
                    const SizedBox(width: 12),
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
                        Icons.lock_outline_rounded,
                        size: 34,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isProvider ? 'Provider login' : 'Welcome back',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isProvider
                          ? 'Sign in with your phone and password\nto manage bookings.'
                          : 'Sign in with your phone and password\nto continue booking.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: AppColors.lightOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PhoneNumberField(
                        key: _phoneFieldKey,
                        controller: _phoneController,
                        label: 'Mobile Number',
                        hintText: '7XXXXXXXXX',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: context.textStyles.bodyLarge?.copyWith(
                          color: AppColors.lightOnSurface,
                          fontWeight: FontWeight.w400,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _login(),
                      style: context.textStyles.bodyMedium?.copyWith(
                        color: AppColors.lightOnSurface,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        hintStyle: context.textStyles.bodyMedium?.copyWith(
                          color: AppColors.lightHint,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: AppColors.lightSurfaceVariant,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 16,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.lightOnSurfaceVariant,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          borderSide: const BorderSide(
                            color: AppColors.brandPrimary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    StylPrimaryButton(
                      label: _busy ? 'Signing in…' : 'Log in',
                      onPressed: _busy ? null : _login,
                      isLoading: _busy,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _goSignUp,
                      child: Text.rich(
                        TextSpan(
                          style: context.textStyles.bodyMedium?.copyWith(
                            color: AppColors.lightOnSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                          children: const [
                            TextSpan(text: 'New user? '),
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
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
