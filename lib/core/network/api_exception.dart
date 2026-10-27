import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(
    String message, {
    this.statusCode,
    this.code,
    this.details,
  }) : message = sanitizeErrorMessage(message);

  final String message;
  final int? statusCode;
  final String? code;
  final Object? details;

  bool get isOffline =>
      code == 'OFFLINE' ||
      code == 'NETWORK_ERROR' ||
      code == 'TIMEOUT' ||
      statusCode == 0;

  @override
  String toString() => message;
}

final _urlPattern = RegExp(
  r'https?://\S+',
  caseSensitive: false,
);
final _hostPattern = RegExp(
  r'\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d{2,5})?\b',
  caseSensitive: false,
);
final _ipPattern = RegExp(
  r'\b\d{1,3}(?:\.\d{1,3}){3}(?::\d{2,5})?\b',
);

/// Strips hosts/URLs so users never see internal API addresses.
String sanitizeErrorMessage(String raw) {
  var msg = raw.trim();
  if (msg.isEmpty) return 'Something went wrong. Please try again.';

  msg = msg.replaceAll(_urlPattern, '');
  msg = msg.replaceAll(_ipPattern, '');
  // Drop leftover hostnames (e.g. after "Failed host lookup: ").
  msg = msg.replaceAll(_hostPattern, '');
  msg = msg
      .replaceAll(RegExp(r'\buri\s*=\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'^[:\-\s,]+|[:\-\s,]+$'), '')
      .trim();

  final lower = msg.toLowerCase();
  if (lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('connection closed') ||
      lower.contains('clientexception') ||
      lower.contains('handshake') ||
      lower.contains('timed out') ||
      lower.contains('timeout') ||
      lower.contains('network') ||
      lower.contains('offline') ||
      lower.contains('no address associated') ||
      lower.contains('software caused connection abort')) {
    return 'No internet connection. Check your network and try again.';
  }

  if (msg.isEmpty ||
      msg.length < 3 ||
      lower == 'exception' ||
      lower.startsWith('error')) {
    return 'Something went wrong. Please try again.';
  }

  return msg;
}

/// Maps any thrown error to a user-safe message (never includes API URLs).
String friendlyErrorMessage(Object error) {
  if (error is ApiException) {
    return sanitizeErrorMessage(error.message);
  }
  if (error is SocketException ||
      error is http.ClientException ||
      error is HandshakeException ||
      error is TlsException ||
      error is HttpException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is FormatException) {
    return 'Unexpected response from server. Please try again.';
  }
  return sanitizeErrorMessage(error.toString());
}

ApiException networkApiException(Object error) {
  return ApiException(
    friendlyErrorMessage(error),
    statusCode: 0,
    code: 'OFFLINE',
    details: error.toString(),
  );
}
