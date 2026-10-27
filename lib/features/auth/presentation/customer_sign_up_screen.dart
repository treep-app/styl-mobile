import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../widgets/auth_form_scaffold.dart';
import '../../../widgets/phone_number_field.dart';
import '../../../widgets/styl_primary_button.dart';
import '../../../widgets/styl_text_field.dart';

/// Customer Sign Up — name + phone on one compact screen.
class CustomerSignUpScreen extends StatefulWidget {
  const CustomerSignUpScreen({super.key});

  @override
  State<CustomerSignUpScreen> createState() => _CustomerSignUpScreenState();
}

class _CustomerSignUpScreenState extends State<CustomerSignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFieldKey = GlobalKey<PhoneNumberFieldState>();
  var _acceptedTerms = false;
  var _busy = false;
  var _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.customerLogin);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty) {
      _toast('Please enter your full name.');
      return;
    }
    if (phone.length < 7) {
      _toast('Enter a valid mobile number.');
      return;
    }
    if (password.length < 6) {
      _toast('Password must be at least 6 characters.');
      return;
    }
    if (!_acceptedTerms) {
      _toast('Please accept Terms & Conditions.');
      return;
    }

    final fullNumber = _phoneFieldKey.currentState?.fullNumber ??
        composeE164(dialCode: '+44', national: phone, isoCountry: 'GB');

    if (tryNormalizeUkPhone(fullNumber) == null &&
        (_phoneFieldKey.currentState?.country.countryCode ?? 'GB') == 'GB') {
      _toast('Enter a valid UK mobile (10 digits, e.g. 07911 123456).');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await context.read<AuthController>().sendOtp(
            phone: fullNumber,
            role: 'CLIENT',
          );
      if (!mounted) return;
      if (result.devCode != null) {
        _toast('Dev OTP: ${result.devCode}');
      }
      Navigator.of(context).pushNamed(
        AppRoutes.customerOtp,
        arguments: OtpArgs(
          phoneNumber: fullNumber,
          fullName: name,
          password: password,
          fromSignUp: true,
        ),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Sign Up',
      subtitle: 'Create your STYL account with your mobile number.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StylTextField(
            controller: _nameController,
            label: 'Full Name',
            hintText: 'Enter Your Name',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          PhoneNumberField(
            key: _phoneFieldKey,
            controller: _phoneController,
          ),
          const SizedBox(height: 16),
          StylTextField(
            controller: _passwordController,
            label: 'Password',
            hintText: 'At least 6 characters',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            suffixIcon: IconButton(
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.lightOnSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: _acceptedTerms,
                  activeColor: AppColors.brandPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (value) {
                    setState(() => _acceptedTerms = value ?? false);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text.rich(
                    TextSpan(
                      style: context.textStyles.bodySmall?.copyWith(
                        color: AppColors.brandPrimary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                      children: const [
                        TextSpan(text: 'Accept all '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          StylPrimaryButton(
            label: _busy ? 'Sending…' : 'Send OTP',
            onPressed: _busy ? null : _submit,
            isLoading: _busy,
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: _goToLogin,
              child: Text.rich(
                TextSpan(
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: AppColors.lightOnSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                  children: const [
                    TextSpan(text: 'Existing user? '),
                    TextSpan(
                      text: 'Login',
                      style: TextStyle(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
