import '../../../core/network/api_client.dart';
import '../../../core/network/api_models.dart';

class NotificationsApi {
  NotificationsApi(this._client);

  final ApiClient _client;

  Future<List<NotificationDto>> list() async {
    final data = await _client.get('/notifications');
    final list = data['notifications'] as List<dynamic>? ?? [];
    return list
        .map((e) => NotificationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final data = await _client.get('/notifications/unread-count');
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<NotificationDto> markRead(String id) async {
    final data = await _client.patch('/notifications/$id/read');
    return NotificationDto.fromJson(
      data['notification'] as Map<String, dynamic>,
    );
  }

  Future<int> markAllRead() async {
    final data = await _client.patch('/notifications/read-all');
    return (data['updated'] as num?)?.toInt() ?? 0;
  }
}
