import 'package:http/http.dart' as http;

import 'api_client.dart';

class AuthApi {
  AuthApi(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String? fcmToken,
  }) async {
    final res = await _client.post('/api/v1/auth/register', {
      'name': name,
      'phone': phone,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'fcm_token': fcmToken,
    });
    if (res['success'] == true && res['data']?['token'] != null) {
      await _client.setToken(res['data']['token'].toString());
    }
    return res;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post('/api/v1/auth/login', {
      'login': email,
      'password': password,
      'app_role': 'provider',
    });
    if (res['success'] == true && res['data']?['token'] != null) {
      await _client.setToken(res['data']['token'].toString());
    }
    return res;
  }

  Future<Map<String, dynamic>> requestOtp({required String phone}) async {
    return _client.post('/api/v1/auth/send-otp', {
      'phone': phone,
      'purpose': 'login',
    });
  }

  Future<Map<String, dynamic>> forgotPassword({required String phone}) {
    return _client.post('/api/v1/auth/forgot-password', {
      'phone': phone,
      'purpose': 'password_reset',
    });
  }

  Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String code,
    required String password,
  }) {
    return _client.post('/api/v1/auth/reset-password', {
      'phone': phone,
      'code': code,
      'password': password,
      'password_confirmation': password,
    });
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final res = await _client.post('/api/v1/auth/verify-otp', {
      'phone': phone,
      'code': code,
      'purpose': 'login',
    });
    if (res['success'] == true && res['data']?['token'] != null) {
      await _client.setToken(res['data']['token'].toString());
    }
    return res;
  }

  Future<Map<String, dynamic>> logout() async {
    final res = await _client.post('/api/v1/auth/logout');
    await _client.setToken(null);
    return res;
  }

  Future<Map<String, dynamic>> me() => _client.get('/api/v1/customer/me');

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data,
      {String? avatarPath, String? coverPath}) async {
    if (avatarPath == null && coverPath == null) {
      return _client.post('/api/v1/auth/update-profile', data);
    }
    final fields = data.map((k, v) => MapEntry(k, '$v'));
    final files = <http.MultipartFile>[];
    if (avatarPath != null) {
      files.add(await http.MultipartFile.fromPath('avatar', avatarPath));
    }
    if (coverPath != null) {
      files.add(await http.MultipartFile.fromPath('cover_image', coverPath));
    }
    return _client.postMultipart('/api/v1/auth/update-profile', fields, files);
  }

  Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _client.post('/api/v1/auth/change-password', {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPassword,
      });
}
