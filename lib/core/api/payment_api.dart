import 'api_client.dart';

class PaymentApi {
  PaymentApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> wallet() => _client.get('/api/v1/wallet');

  Future<Map<String, dynamic>> transactions() =>
      _client.get('/api/v1/wallet/transactions');

  /// Wallet ledger: every movement with running balance.
  Future<Map<String, dynamic>> ledger() => _client.get('/api/v1/wallet/ledger');

  Future<Map<String, dynamic>> withdrawals() =>
      _client.get('/api/v1/wallet/withdrawals');

  Future<Map<String, dynamic>> withdraw(Map<String, dynamic> payload) =>
      _client.post('/api/v1/wallet/withdraw', payload);
}
