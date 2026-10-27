import '../../../core/network/api_client.dart';
import '../../../core/utils/media_url.dart';

class UploadsApi {
  UploadsApi(this._client);

  final ApiClient _client;

  /// Upload an image; returns a public URL to save on user/shop records.
  ///
  /// Sends as JPEG. iOS gallery picks often report HEIC / no mime type; with
  /// `imageQuality` on the picker the file bytes are already JPEG.
  Future<UploadResult> uploadImage({
    required List<int> bytes,
    required String filename,
    String purpose = 'general',
  }) async {
    final data = await _client.uploadFile(
      '/uploads',
      bytes: bytes,
      filename: _jpegFilename(filename),
      fieldName: 'file',
      fields: {'purpose': purpose},
      contentType: 'image/jpeg',
    );
    return UploadResult.fromJson(data);
  }

  static String _jpegFilename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'upload.jpg';
    final dot = trimmed.lastIndexOf('.');
    if (dot <= 0) return '$trimmed.jpg';
    return '${trimmed.substring(0, dot)}.jpg';
  }
}

class UploadResult {
  const UploadResult({
    required this.url,
    required this.key,
    required this.provider,
    required this.purpose,
  });

  final String url;
  final String key;
  final String provider;
  final String purpose;

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      // Rewrite localhost → device-reachable API host before saving to records.
      url: resolveMediaUrlRequired(json['url'] as String? ?? ''),
      key: json['key'] as String? ?? '',
      provider: json['provider'] as String? ?? 'local',
      purpose: json['purpose'] as String? ?? 'general',
    );
  }
}
