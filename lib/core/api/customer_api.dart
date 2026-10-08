import 'api_client.dart';

class CustomerApi {
  CustomerApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> dashboard() =>
      _client.get('/api/v1/customer/dashboard');

  Future<Map<String, dynamic>> listRequests(
          {String? status, int page = 1, int perPage = 15}) =>
      _client.get('/api/v1/customer/requests', query: {
        if (status != null) 'status': status,
        'page': page,
        'per_page': perPage,
      });

  Future<Map<String, dynamic>> getRequest(int id) =>
      _client.get('/api/v1/customer/requests/$id');

  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> payload) =>
      _client.post('/api/v1/customer/requests', payload);

  Future<Map<String, dynamic>> cancelRequest(int id, {String? reason}) =>
      _client.post('/api/v1/customer/requests/$id/cancel', {
        if (reason != null) 'reason': reason,
      });

  Future<Map<String, dynamic>> listOrders({String? status}) =>
      _client.get('/api/v1/customer/orders',
          query: status != null ? {'status': status} : null);

  Future<Map<String, dynamic>> getOrder(int id) =>
      _client.get('/api/v1/customer/orders/$id');

  Future<Map<String, dynamic>> payments() =>
      _client.get('/api/v1/customer/payments');

  Future<Map<String, dynamic>> dashboardData() => dashboard();
}
