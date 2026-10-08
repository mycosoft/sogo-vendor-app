import 'api_client.dart';

class LocationsApi {
  LocationsApi(this._client);
  final ApiClient _client;

  Future<List<String>> districts() async {
    final res = await _client.get('/locations/districts');
    return List<String>.from(res['districts'] ?? const []);
  }

  Future<List<Map<String, dynamic>>> cities(String district) async {
    final res =
        await _client.get('/locations/cities', query: {'district': district});
    return List<Map<String, dynamic>>.from(res['cities'] ?? const []);
  }
}
