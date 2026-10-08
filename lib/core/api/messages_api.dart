import 'api_client.dart';

/// Mobile chat API — implicit conversations (Message pairs) + SOGO Support.
class MessagesApi {
  MessagesApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> threads() =>
      _client.get('/api/v1/messages/threads');

  Future<Map<String, dynamic>> supportUser() =>
      _client.get('/api/v1/messages/support');

  Future<Map<String, dynamic>> thread(int userId, {String? since}) =>
      _client.get('/api/v1/messages/$userId',
          query: since != null ? {'since': since} : null);

  Future<Map<String, dynamic>> send(int userId, String body) =>
      _client.post('/api/v1/messages/$userId', {'body': body});
}
