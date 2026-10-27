import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Native Stripe Payment Sheet helpers (pay + save card).
abstract final class StripePayments {
  static const urlScheme = 'flutterstripe';

  /// Set this (and the matching iOS merchant capability) to enable Apple Pay.
  /// Leave empty until Apple Pay is enrolled for STYL.
  static const String appleMerchantId = String.fromEnvironment(
    'STRIPE_APPLE_MERCHANT_ID',
    defaultValue: '',
  );

  static bool get applePayEnabled => appleMerchantId.isNotEmpty;

  static bool get walletEnabled {
    if (kIsWeb) return false;
    if (Platform.isIOS) return applePayEnabled;
    return Platform.isAndroid;
  }

  static Future<void> configure({required String publishableKey}) async {
    if (!publishableKey.startsWith('pk_')) {
      throw StateError(
        'Invalid Stripe publishable key. Expected pk_test_… or pk_live_…',
      );
    }
    Stripe.publishableKey = publishableKey;
    Stripe.urlScheme = urlScheme;
    if (applePayEnabled) {
      Stripe.merchantIdentifier = appleMerchantId;
    }
    await Stripe.instance.applySettings();
  }

  static Future<void> _waitForUiSettle() async {
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await SchedulerBinding.instance.endOfFrame;
  }

  static SetupPaymentSheetParameters _sheetParams({
    String? paymentIntentClientSecret,
    String? setupIntentClientSecret,
    String? customerId,
    String? ephemeralKeySecret,
    required String merchantDisplayName,
    required bool wallets,
  }) {
    return SetupPaymentSheetParameters(
      paymentIntentClientSecret: paymentIntentClientSecret,
      setupIntentClientSecret: setupIntentClientSecret,
      customerId: customerId,
      customerEphemeralKeySecret: ephemeralKeySecret,
      merchantDisplayName: merchantDisplayName,
      style: ThemeMode.system,
      returnURL: '$urlScheme://safepay',
      allowsDelayedPaymentMethods: false,
      applePay: wallets && applePayEnabled
          ? PaymentSheetApplePay(merchantCountryCode: 'GB')
          : null,
      googlePay: wallets && !kIsWeb && Platform.isAndroid
          ? const PaymentSheetGooglePay(
              merchantCountryCode: 'GB',
              testEnv: true,
            )
          : null,
    );
  }

  static Future<bool> _present({
    required SetupPaymentSheetParameters params,
    required String label,
  }) async {
    debugPrint('[stripe] init $label…');
    await Stripe.instance.initPaymentSheet(paymentSheetParameters: params);
    await _waitForUiSettle();
    try {
      debugPrint('[stripe] present $label…');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('[stripe] $label completed');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[stripe] $label cancelled by user');
        return false;
      }
      debugPrint(
        '[stripe] $label error code=${e.error.code} '
        'message=${e.error.message} localized=${e.error.localizedMessage}',
      );
      rethrow;
    }
  }

  /// Presents Payment Sheet for a PaymentIntent (pay now).
  static Future<bool> presentPaymentSheet({
    required String clientSecret,
    String merchantDisplayName = 'STYL',
  }) async {
    try {
      return await _present(
        label: 'Payment Sheet',
        params: _sheetParams(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          wallets: true,
        ),
      );
    } catch (e) {
      final text = e.toString();
      if (!text.contains('merchantIdentifier') &&
          !text.contains('Apple Pay')) {
        rethrow;
      }
      debugPrint('[stripe] retrying Payment Sheet without Apple Pay: $e');
      return _present(
        label: 'Payment Sheet',
        params: _sheetParams(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          wallets: false,
        ),
      );
    }
  }

  /// Presents Payment Sheet to save a card (SetupIntent).
  static Future<bool> presentSetupSheet({
    required String setupIntentClientSecret,
    required String customerId,
    required String ephemeralKeySecret,
    String merchantDisplayName = 'STYL',
  }) async {
    try {
      return await _present(
        label: 'Setup Sheet',
        params: _sheetParams(
          setupIntentClientSecret: setupIntentClientSecret,
          customerId: customerId,
          ephemeralKeySecret: ephemeralKeySecret,
          merchantDisplayName: merchantDisplayName,
          wallets: true,
        ),
      );
    } catch (e) {
      final text = e.toString();
      if (!text.contains('merchantIdentifier') &&
          !text.contains('Apple Pay')) {
        rethrow;
      }
      return _present(
        label: 'Setup Sheet',
        params: _sheetParams(
          setupIntentClientSecret: setupIntentClientSecret,
          customerId: customerId,
          ephemeralKeySecret: ephemeralKeySecret,
          merchantDisplayName: merchantDisplayName,
          wallets: false,
        ),
      );
    }
  }
}
