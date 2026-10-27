/// STYL platform booking fee — must match backend `computeBookingFee`.
const kBookingFeeGbp = 1.0;

double roundGbp(double amount) => (amount * 100).round() / 100;

/// Flat £1 platform fee for now.
double computeStylBookingFee([double _ = 0]) => kBookingFeeGbp;

/// Amount collected online now.
/// Pay at salon → £1 fee only. Pay online → service + £1 fee.
double stylAmountDueNow({
  required bool payAtSalon,
  required double serviceAmount,
}) {
  if (payAtSalon) return kBookingFeeGbp;
  final service = serviceAmount.isFinite && serviceAmount > 0 ? serviceAmount : 0;
  return roundGbp(service + kBookingFeeGbp);
}

String stylFeeLabel(double amount, {String currency = 'GBP'}) {
  final symbol = switch (currency) {
    'GBP' => '£',
    'USD' => '\$',
    'EUR' => '€',
    _ => '$currency ',
  };
  if (amount == amount.roundToDouble()) {
    return '$symbol${amount.round()}';
  }
  return '$symbol${amount.toStringAsFixed(2)}';
}
