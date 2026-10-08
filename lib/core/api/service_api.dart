import 'api_client.dart';

class ServiceApi {
  ServiceApi(this._client);
  final ApiClient _client;

  Future<List<dynamic>> categories() async {
    final res = await _client.get('/api/v1/service-categories');
    return List<dynamic>.from(res['data'] as List? ?? const []);
  }
}
