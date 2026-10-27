import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/payments/stripe_payments.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';

/// Save a card via Stripe Payment Sheet (SetupIntent) — no raw card data.
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  var _busy = false;

  Future<void> _saveWithStripe() async {
    setState(() => _busy = true);
    try {
      final payments = context.read<AuthController>().paymentsApi;
      final setup = await payments.createSetupIntent();
      if (setup.setupIntentClientSecret.isEmpty ||
          setup.publishableKey.isEmpty) {
        throw ApiException(
          'Card setup is not available right now. Please try again later.',
          code: 'SETUP_UNAVAILABLE',
        );
      }

      await StripePayments.configure(publishableKey: setup.publishableKey);
      final saved = await StripePayments.presentSetupSheet(
        setupIntentClientSecret: setup.setupIntentClientSecret,
        customerId: setup.customerId,
        ephemeralKeySecret: setup.ephemeralKeySecret,
      );

      if (!mounted) return;
      if (!saved) {
        // User cancelled the sheet.
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card saved')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      final raw = e.error.localizedMessage ??
          e.error.message ??
          'Could not save card';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(raw))),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stripe plugin not ready. Fully stop the app and run flutter run again (not hot restart).',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text(
          'Add Credit/Debit Card',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Secure card entry',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Your card details are entered securely with Stripe. '
                        'STYL never stores your full card number.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Color(0xFF575757),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'You’ll be able to use this card for wallet top-ups '
                        'and appointment payments.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF8A8A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: StylPrimaryButton(
                label: _busy ? 'Opening…' : 'Add card with Stripe',
                onPressed: _busy ? null : _saveWithStripe,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
