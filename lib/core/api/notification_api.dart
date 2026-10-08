import 'api_client.dart';

class NotificationApi {
  NotificationApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> unread() =>
      _client.get('/api/v1/notifications/unread');

  Future<Map<String, dynamic>> list({int perPage = 25, int page = 1}) => _client
      .get('/api/v1/notifications', query: {'per_page': perPage, 'page': page});

  Future<Map<String, dynamic>> markRead(int id) =>
      _client.post('/api/v1/notifications/$id/read');

  Future<Map<String, dynamic>> markAllRead() =>
      _client.post('/api/v1/notifications/read-all');
}
