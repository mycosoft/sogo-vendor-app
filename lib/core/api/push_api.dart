import 'api_client.dart';

class PushApi {
  PushApi(this._client);
  final ApiClient _client;

  Future<void> register(
      {required String token,
      required String app,
      String platform = 'android'}) async {
    await _client.post('/api/v1/devices/register', {
      'token': token,
      'platform': platform,
      'app': app,
    });
  }

  Future<void> unregister({required String token}) async {
    await _client.post('/api/v1/devices/unregister', {'token': token});
  }
}
