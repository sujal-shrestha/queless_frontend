import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // For Android emulator use 10.0.2.2
  static const String baseUrl = 'http://10.0.2.2:5000';

  static Future<Map<String, dynamic>> signupUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/signup');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _saveToken(data['token']);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Error'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String id,
    required String password,
    required String role, // 'user' or 'staff'
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/login');

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'password': password,
        'role': role,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _saveToken(data['token']);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'message': data['message'] ?? 'Error'};
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
}
