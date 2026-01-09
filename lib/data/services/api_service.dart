import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5001';
  static const Duration _timeout = Duration(seconds: 12);

  static Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ======================
  // AUTH
  // ======================
  static Future<Map<String, dynamic>> signupUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/signup');

    try {
      final res = await http
          .post(
            url,
            headers: _headers,
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(_timeout);

      final parsed = _parseResponse(res);
      print('[SIGNUP] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = parsed['token'];
        if (token is String && token.isNotEmpty) {
          await _saveToken(token);
        }
        return {'success': true, 'data': parsed};
      }

      return {
        'success': false,
        'message': parsed['message'] ?? 'Signup failed (${res.statusCode})',
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out. Is the server running on 5001?'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String id,
    required String password,
    required String role,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    try {
      final res = await http
          .post(
            url,
            headers: _headers,
            body: jsonEncode({
              'id': id,
              'password': password,
              'role': role,
            }),
          )
          .timeout(_timeout);

      final parsed = _parseResponse(res);
      print('[LOGIN] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = parsed['token'];
        if (token is String && token.isNotEmpty) {
          await _saveToken(token);
        }
        return {'success': true, 'data': parsed};
      }

      return {
        'success': false,
        'message': parsed['message'] ?? 'Login failed (${res.statusCode})',
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out. Is the server running on 5001?'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ======================
  // TOKEN
  // ======================
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    print('[TOKEN] Saved token len=${token.length}');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    print('[TOKEN] Read token? ${t != null && t.isNotEmpty}');
    return t;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    print('[TOKEN] Removed token');
  }

  // ======================
  // PROFILE
  // ======================
  static Future<Map<String, dynamic>> fetchProfile() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/auth/profile');

    try {
      final res = await http
          .get(
            url,
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final parsed = _parseResponse(res);
      print('[PROFILE GET] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        // backend might return {user:{...}} or {...}
        final data = (parsed['user'] is Map<String, dynamic>) ? parsed['user'] : parsed;
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': parsed['message'] ?? 'Failed to load profile (${res.statusCode})',
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NOTE: If your backend is PUT instead of PATCH, change http.patch -> http.put
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/auth/profile');

    try {
      final res = await http
          .patch(
            url,
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'name': name,
              'email': email,
              'phone': phone ?? '',
            }),
          )
          .timeout(_timeout);

      final parsed = _parseResponse(res);
      print('[PROFILE PATCH] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final data = (parsed['user'] is Map<String, dynamic>) ? parsed['user'] : parsed;
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'message': parsed['message'] ?? 'Update failed (${res.statusCode})',
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // NOTE: If your backend is POST instead of PUT, change http.put -> http.post
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/auth/change-password');

    try {
      final res = await http
          .put(
            url,
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);

      final parsed = _parseResponse(res);
      print('[PASSWORD PUT] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': parsed};
      }

      return {
        'success': false,
        'message': parsed['message'] ?? 'Password change failed (${res.statusCode})',
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ======================
  // HELPERS
  // ======================
  static bool _isOk(int code) => code >= 200 && code < 300;

  static Map<String, dynamic> _parseResponse(http.Response res) {
    final body = res.body;
    if (body.isEmpty) return {'message': 'Empty response from server'};

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'message': decoded.toString()};
    } catch (_) {
      return {'message': body};
    }
  }
}
