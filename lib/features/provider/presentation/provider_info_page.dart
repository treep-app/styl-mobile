import 'package:flutter/material.dart';

/// Shared simple content page for About / Privacy / Terms / Help.
class ProviderInfoPage extends StatelessWidget {
  const ProviderInfoPage({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(
          body,
          style: const TextStyle(
            fontSize: 14,
            height: 1.55,
            color: Color(0xFF575757),
          ),
        ),
      ),
    );
  }
}

const kStylAboutBody =
    'STYL helps you book salon and barber appointments the way you want them — '
    'how you want it, when you want it.\n\n'
    'Customers discover nearby salons and freelancers, pick a specialist and '
    'time, and pay securely in the app. Service providers manage their salon, '
    'team, availability, and bookings from one place.\n\n'
    'STYL is built for iOS and Android.';

const kStylPrivacyBody =
    'We collect the information you provide to create and use your STYL account, '
    'including your phone number, name, optional email, profile photo, and '
    'booking details.\n\n'
    'Payment details are processed by our payment partners (such as Stripe). '
    'STYL does not store full card numbers on our servers.\n\n'
    'We use your data to run bookings, send service messages (for example OTP '
    'codes and appointment updates), improve the product, and keep accounts '
    'secure.\n\n'
    'You can update your profile in Settings. For privacy questions, contact '
    'support through Help in the app.';

const kStylTermsBody =
    'By using STYL you agree to book and provide services in good faith.\n\n'
    'Customers are responsible for attending booked appointments or cancelling '
    'in time according to salon policy. Providers are responsible for honouring '
    'confirmed bookings and keeping availability accurate.\n\n'
    'Payments, refunds, and no-show rules may depend on the salon and the '
    'payment method you choose. STYL may suspend accounts that abuse the '
    'platform.\n\n'
    'These terms may be updated as STYL grows. Continued use of the app means '
    'you accept the latest version.';

const kStylHelpBody =
    'Need a hand?\n\n'
    '• Bookings: open Appointments to view, cancel, or check payment status.\n'
    '• Payments: use Wallet (Stripe) or cash at the salon. Cards are managed '
    'securely through Stripe.\n'
    '• Profile: update your name and photo in Personal Info. Email can be set '
    'once and cannot be changed afterwards.\n'
    '• Salon owners: manage salon details and team under My Salon in Settings.\n\n'
    'If something still looks wrong, pull to refresh the screen, check your '
    'internet connection, then try again.';
