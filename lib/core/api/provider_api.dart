import 'dart:convert';

import 'package:http/http.dart' as http;
import 'api_client.dart';

class ProviderApi {
  ProviderApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> me() => _client.get('/api/v1/provider/me');

  Future<Map<String, dynamic>> registerProvider(Map<String, dynamic> payload) =>
      _client.post('/api/v1/provider/register', payload);

  /// Multipart vendor registration carrying KYC files and images.
  Future<Map<String, dynamic>> registerProviderMultipart(
    Map<String, String> fields,
    List<http.MultipartFile> files,
  ) =>
      _client.postMultipart('/api/v1/provider/register', fields, files);

  Future<Map<String, dynamic>> update(Map<String, dynamic> payload,
      {String? logoPath, String? coverPath}) async {
    if (logoPath == null && coverPath == null) {
      return _client.post('/api/v1/provider/update', payload);
    }
    // Multipart carries strings only: booleans as 1/0 (Laravel's boolean
    // rule rejects 'true'/'false'), maps/lists as JSON, nulls omitted.
    final fields = <String, String>{};
    payload.forEach((k, v) {
      if (v == null) return;
      if (v is bool) {
        fields[k] = v ? '1' : '0';
      } else if (v is Map || v is List) {
        fields[k] = jsonEncode(v);
      } else {
        fields[k] = v.toString();
      }
    });
    final files = <http.MultipartFile>[];
    if (logoPath != null) {
      files.add(await http.MultipartFile.fromPath('logo', logoPath));
    }
    if (coverPath != null) {
      files.add(await http.MultipartFile.fromPath('cover_image', coverPath));
    }
    return _client.postMultipart('/api/v1/provider/update', fields, files);
  }

  Future<Map<String, dynamic>> requests() =>
      _client.get('/api/v1/provider/requests');

  Future<Map<String, dynamic>> jobShow(int id) =>
      _client.get('/api/v1/provider/requests/$id');

  /// Reviews customers left for this vendor (by user id).
  Future<Map<String, dynamic>> reviewsFor(int userId) =>
      _client.get('/api/v1/reviews/provider/$userId');

  Future<Map<String, dynamic>> availableJobs() =>
      _client.get('/api/v1/provider/requests/available');

  Future<Map<String, dynamic>> acceptJob(int id) =>
      _client.post('/api/v1/provider/requests/$id/accept');

  /// Pass on a job offer. Recorded as tried (escalation skips it) —
  /// never a penalty, the job just routes to someone else.
  Future<Map<String, dynamic>> declineJob(int id) =>
      _client.post('/api/v1/provider/requests/$id/decline');

  Future<Map<String, dynamic>> updateStatus(int id,
          {required String status, double? finalPrice}) =>
      _client.put('/api/v1/provider/requests/$id/status', {
        'status': status,
        if (finalPrice != null) 'final_price': finalPrice,
      });

  Future<Map<String, dynamic>> setOnline(bool isOnline) => _client.post(
      '/api/v1/provider/online-status',
      {'is_online': isOnline, 'is_available': isOnline});

  Future<Map<String, dynamic>> updateLocation(double lat, double lng) =>
      _client.post('/api/v1/provider/location', {'lat': lat, 'lng': lng});

  Future<Map<String, dynamic>> services() =>
      _client.get('/api/v1/provider/services');

  Future<Map<String, dynamic>> addService(Map<String, dynamic> payload) =>
      _client.post('/api/v1/provider/services', payload);

  Future<Map<String, dynamic>> toggleService(int id) =>
      _client.patch('/api/v1/provider/services/$id/toggle');

  Future<Map<String, dynamic>> deleteService(int id) =>
      _client.delete('/api/v1/provider/services/$id');

  Future<Map<String, dynamic>> updateServicePrice(int id, double price) =>
      _client.patch('/api/v1/provider/services/$id', {'price': price});

  Future<Map<String, dynamic>> inventory() =>
      _client.get('/api/v1/provider/inventory');

  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> payload,
      {String? imagePath}) async {
    if (imagePath == null) {
      return _client.post('/api/v1/provider/inventory', payload);
    }
    final fields = <String, String>{};
    payload.forEach((k, v) {
      if (v == null) return;
      if (v is bool) {
        fields[k] = v ? '1' : '0';
      } else {
        fields[k] = v.toString();
      }
    });
    final files = [await http.MultipartFile.fromPath('main_image', imagePath)];
    return _client.postMultipart('/api/v1/provider/inventory', fields, files);
  }

  Future<Map<String, dynamic>> updateProduct(
      int id, Map<String, dynamic> payload,
      {String? imagePath}) async {
    if (imagePath == null) {
      return _client.post('/api/v1/provider/inventory/$id', payload);
    }
    final fields = <String, String>{};
    payload.forEach((k, v) {
      if (v == null) return;
      if (v is bool) {
        fields[k] = v ? '1' : '0';
      } else {
        fields[k] = v.toString();
      }
    });
    final files = [await http.MultipartFile.fromPath('main_image', imagePath)];
    return _client.postMultipart(
        '/api/v1/provider/inventory/$id', fields, files);
  }

  Future<Map<String, dynamic>> deleteProduct(int id) =>
      _client.delete('/api/v1/provider/inventory/$id');

  Future<Map<String, dynamic>> orders({String? status}) =>
      _client.get('/api/v1/provider/orders',
          query: status != null ? {'status': status} : null);

  Future<Map<String, dynamic>> orderShow(int id) =>
      _client.get('/api/v1/provider/orders/$id');

  Future<Map<String, dynamic>> updateOrderStatus(int id, String status) =>
      _client.patch('/api/v1/provider/orders/$id/status', {'status': status});

  Future<Map<String, dynamic>> markOrderPaid(int id) =>
      _client.post('/api/v1/provider/orders/$id/mark-paid');

  Future<Map<String, dynamic>> invoices({String? status}) =>
      _client.get('/api/v1/provider/invoices',
          query: status != null ? {'status': status} : null);

  Future<Map<String, dynamic>> addInvoice(Map<String, dynamic> payload) =>
      _client.post('/api/v1/provider/invoices', payload);

  Future<Map<String, dynamic>> invoiceShow(int id) =>
      _client.get('/api/v1/provider/invoices/$id');
  Future<Map<String, dynamic>> updateInvoiceStatus(int id, String status) =>
      _client.patch('/api/v1/provider/invoices/$id/status', {'status': status});

  Future<Map<String, dynamic>> recordCashPayment(int id) =>
      _client.post('/api/v1/provider/invoices/$id/record-cash');

  Future<Map<String, dynamic>> customers() =>
      _client.get('/api/v1/provider/customers');

  Future<Map<String, dynamic>> invoicePaymentLink(int id) =>
      _client.post('/api/v1/provider/invoices/$id/payment-link');
}
