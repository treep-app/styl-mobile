import '../config/api_config.dart';

/// Rewrites local-dev media URLs so devices can load them.
///
/// The API often returns `http://localhost:3000/uploads/...` when
/// `PUBLIC_API_URL` is localhost. Simulators may load those; physical phones
/// cannot. Swap the host/port to match [ApiConfig.baseUrl].
String? resolveMediaUrl(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  if (trimmed.isEmpty) return trimmed;

  final api = Uri.tryParse(ApiConfig.baseUrl);
  if (api == null || api.host.isEmpty) return trimmed;

  final origin =
      '${api.scheme}://${api.host}${api.hasPort ? ':${api.port}' : ''}';

  // Relative upload paths from older payloads.
  if (trimmed.startsWith('/')) {
    return '$origin$trimmed';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme) {
    return trimmed.startsWith('uploads/') ? '$origin/$trimmed' : trimmed;
  }

  final host = uri.host.toLowerCase();
  final isLoopback =
      host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
  if (!isLoopback) return trimmed;

  return uri
      .replace(
        scheme: api.scheme,
        host: api.host,
        port: api.hasPort ? api.port : null,
      )
      .toString();
}

/// Non-null variant for list mapping.
String resolveMediaUrlRequired(String url) => resolveMediaUrl(url) ?? url;
