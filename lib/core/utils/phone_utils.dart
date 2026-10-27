/// STYL phone helpers — UK-first E.164 normalization.
///
/// UK mobiles (Ofcom): national `0` + 10-digit NSN starting with `7`,
/// stored as `+447XXXXXXXXX`.
///
/// All of these become `+447911123456`:
/// - `07911123456` / `07 911 123456`
/// - `7911123456`
/// - `447911123456` / `+447911123456`
/// - `+44(0)7911123456`
library;

String _digitsOnly(String input) => input.replaceAll(RegExp(r'\D'), '');

String _compact(String input) {
  final trimmed = input.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = _digitsOnly(trimmed);
  return hasPlus ? '+$digits' : digits;
}

/// Try to coerce [input] into a UK E.164 number. Returns null if not UK-like.
String? tryNormalizeUkPhone(String input) {
  var raw = _compact(input);
  if (raw.isEmpty) return null;

  raw = raw.replaceFirst(RegExp(r'^\+440+'), '+44');
  raw = raw.replaceFirst(RegExp(r'^440+'), '44');

  var digits = _digitsOnly(raw);

  if (digits.startsWith('44')) {
    digits = digits.substring(2).replaceFirst(RegExp(r'^0+'), '');
  } else if (digits.startsWith('0')) {
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
  } else if (raw.startsWith('+') && !raw.startsWith('+44')) {
    return null;
  }

  // UK mobile NSN: 10 digits starting with 7 (e.g. 7911123456).
  if (RegExp(r'^7\d{9}$').hasMatch(digits)) {
    return '+44$digits';
  }

  return null;
}

/// Normalize UI / API phone strings to E.164 (`+447700…`).
String toE164(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;

  final uk = tryNormalizeUkPhone(trimmed);
  if (uk != null) return uk;

  var compacted = _compact(trimmed);
  if (!compacted.startsWith('+')) {
    compacted = '+${_digitsOnly(compacted)}';
  }
  return _stripTrunkZero(compacted);
}

/// Join dial code (`+44`) with a national number (`07…` or `7…`).
String composeE164({
  required String dialCode,
  required String national,
  String? isoCountry,
}) {
  final code = dialCode.trim().startsWith('+')
      ? dialCode.trim()
      : '+${_digitsOnly(dialCode)}';
  final local = national.trim();
  final isUk = isoCountry?.toUpperCase() == 'GB' ||
      code == '+44' ||
      code == '44';

  if (isUk) {
    final fromLocal = tryNormalizeUkPhone(local);
    if (fromLocal != null) return fromLocal;
    final withCc = tryNormalizeUkPhone(
      local.startsWith('+') ? local : '+44$local',
    );
    if (withCc != null) return withCc;
  }

  if (local.isEmpty) return code;
  return toE164('$code$local');
}

String _stripTrunkZero(String e164) {
  const trunkZeroCodes = [
    '353',
    '27',
    '61',
    '64',
    '49',
    '33',
    '39',
    '34',
    '91',
    '256',
    '254',
    '233',
    '234',
  ];

  for (final cc in trunkZeroCodes) {
    final prefix = '+$cc';
    if (e164.startsWith('${prefix}0')) {
      return '$prefix${e164.substring(prefix.length).replaceFirst(RegExp(r'^0+'), '')}';
    }
  }
  return e164;
}
