import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import 'api_exception.dart';

typedef TokenReader = Future<String?> Function();
typedef TokenRefresher = Future<bool> Function();

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.readAccessToken,
    this.tryRefresh,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final TokenReader? readAccessToken;
  final TokenRefresher? tryRefresh;
  final String baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('GET', path, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('PATCH', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('PUT', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = true,
  }) {
    return _send('DELETE', path, auth: auth);
  }

  /// Multipart image upload → `{ url, key, provider, purpose }`.
  Future<Map<String, dynamic>> uploadFile(
    String path, {
    required List<int> bytes,
    required String filename,
    required String fieldName,
    Map<String, String>? fields,
    String contentType = 'image/jpeg',
    bool auth = true,
  }) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (auth) {
        final token = await readAccessToken?.call();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      final uri = _uri(path);
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      if (fields != null) {
        request.fields.addAll(fields);
      }
      final parts = contentType.split('/');
      final mediaType = parts.length == 2
          ? MediaType(parts[0], parts[1])
          : MediaType('image', 'jpeg');
      request.files.add(
        http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: mediaType,
        ),
      );

      final streamed = await _http.send(request).timeout(
            const Duration(seconds: 60),
          );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401 && auth && tryRefresh != null) {
        final ok = await tryRefresh!();
        if (ok) {
          return await uploadFile(
            path,
            bytes: bytes,
            filename: filename,
            fieldName: fieldName,
            fields: fields,
            contentType: contentType,
            auth: auth,
          );
        }
      }

      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and try again.',
        statusCode: 0,
        code: 'TIMEOUT',
      );
    } on SocketException catch (e) {
      throw networkApiException(e);
    } on http.ClientException catch (e) {
      throw networkApiException(e);
    } on HandshakeException catch (e) {
      throw networkApiException(e);
    } on TlsException catch (e) {
      throw networkApiException(e);
    } on HttpException catch (e) {
      throw networkApiException(e);
    } on FormatException {
      throw ApiException(
        'Unexpected response from server. Please try again.',
        code: 'BAD_RESPONSE',
      );
    } catch (e) {
      throw ApiException(friendlyErrorMessage(e), code: 'UNKNOWN');
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
    bool retried = false,
  }) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (auth) {
        final token = await readAccessToken?.call();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      final uri = _uri(path, query);
      final encoded = body == null ? null : jsonEncode(body);

      late http.Response response;
      Future<http.Response> call() {
        switch (method) {
          case 'GET':
            return _http.get(uri, headers: headers);
          case 'POST':
            return _http.post(uri, headers: headers, body: encoded);
          case 'PATCH':
            return _http.patch(uri, headers: headers, body: encoded);
          case 'PUT':
            return _http.put(uri, headers: headers, body: encoded);
          case 'DELETE':
            return _http.delete(uri, headers: headers);
          default:
            throw ApiException('Unsupported method $method');
        }
      }

      response = await call().timeout(const Duration(seconds: 30));

      if (response.statusCode == 401 &&
          auth &&
          !retried &&
          tryRefresh != null) {
        final ok = await tryRefresh!();
        if (ok) {
          return await _send(
            method,
            path,
            body: body,
            query: query,
            auth: auth,
            retried: true,
          );
        }
      }

      return _decode(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        'Request timed out. Check your connection and try again.',
        statusCode: 0,
        code: 'TIMEOUT',
      );
    } on SocketException catch (e) {
      throw networkApiException(e);
    } on http.ClientException catch (e) {
      throw networkApiException(e);
    } on HandshakeException catch (e) {
      throw networkApiException(e);
    } on TlsException catch (e) {
      throw networkApiException(e);
    } on HttpException catch (e) {
      throw networkApiException(e);
    } on FormatException {
      throw ApiException(
        'Unexpected response from server. Please try again.',
        code: 'BAD_RESPONSE',
      );
    } catch (e) {
      throw ApiException(friendlyErrorMessage(e), code: 'UNKNOWN');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json = {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } on FormatException {
        final status = response.statusCode;
        // Non-JSON usually means nginx/HTML (502 during reload) or wrong URL.
        final hint = status >= 500
            ? 'Server error ($status). Please try again in a moment.'
            : status == 404
                ? 'API route not found. Check the app is pointed at production.'
                : 'Unexpected response from server ($status). Please try again.';
        throw ApiException(
          hint,
          statusCode: status,
          code: 'BAD_RESPONSE',
        );
      }
    }

    final success = json['success'] == true;
    final status = response.statusCode;
    if (status >= 200 &&
        status < 300 &&
        (success || !json.containsKey('success'))) {
      final data = json['data'];
      if (data is Map<String, dynamic>) return data;
      return json;
    }

    final err = json['error'];
    String message = 'Request failed. Please try again.';
    String? code;
    Object? details;
    if (err is Map<String, dynamic>) {
      message = (err['message'] as String?) ?? message;
      code = err['code'] as String?;
      details = err['details'];
    } else if (json['message'] is String) {
      message = json['message'] as String;
    }

    throw ApiException(
      sanitizeErrorMessage(message),
      statusCode: status,
      code: code,
      details: details,
    );
  }
}
