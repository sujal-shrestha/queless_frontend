import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5001';
  static const Duration _timeout = Duration(seconds: 12);

  // ======================
  // BASE HEADERS
  // ======================

  static Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      ..._headers,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _authHeadersNoContentType() async {
    // For GET/DELETE you can keep it simple
    final token = await getToken();
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

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

      final parsed = _decode(res);
      print('[SIGNUP] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = _extractToken(parsed);
        if (token != null) await _saveToken(token);

        return {
          'success': true,
          'data': _unwrapData(parsed),
          'statusCode': res.statusCode,
        };
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Signup failed (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out. Is the server running on 5001?'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Optional (if you implement /api/auth/signup-staff)
  static Future<Map<String, dynamic>> signupStaff({
    required String username,
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/api/auth/signup-staff');

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

      final parsed = _decode(res);
      print('[SIGNUP STAFF] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = _extractToken(parsed);
        if (token != null) await _saveToken(token);

        return {
          'success': true,
          'data': _unwrapData(parsed),
          'statusCode': res.statusCode,
        };
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Staff signup failed (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String id,
    required String password,
    required String role, // "user" or "staff"
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

      final parsed = _decode(res);
      print('[LOGIN] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = _extractToken(parsed);
        if (token != null) await _saveToken(token);

        // 🔥 extra debug (so you can confirm token really saved)
        final saved = await getToken();
        print('[LOGIN] token saved? ${saved != null && saved.isNotEmpty}');

        return {
          'success': true,
          'data': _unwrapData(parsed),
          'statusCode': res.statusCode,
        };
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Login failed (${res.statusCode})',
        'data': parsed,
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
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/auth/profile');

    try {
      final res = await http
          .get(
            url,
            headers: await _authHeadersNoContentType(),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[PROFILE GET] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to load profile (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile({
  required String name,
  required String email,
  String? phone,
  String? address,

  // ✅ Optional: send profile image as either:
  // 1) a base64 string (recommended for your current setup), OR
  // 2) an already-hosted image URL
  String? profileImageBase64,
  String? profileImageUrl,
}) async {
  final token = await getToken();
  if (token == null || token.isEmpty) {
    return {'success': false, 'message': 'Not logged in'};
  }

  final url = Uri.parse('$baseUrl/api/auth/profile');

  try {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'phone': phone ?? '',
      'address': address ?? '',
    };

    // ✅ Only include image fields if provided (prevents breaking older backends)
    if (profileImageBase64 != null && profileImageBase64.trim().isNotEmpty) {
      body['profileImageBase64'] = profileImageBase64.trim();
    }
    if (profileImageUrl != null && profileImageUrl.trim().isNotEmpty) {
      body['profileImageUrl'] = profileImageUrl.trim();
    }

    final res = await http
        .patch(
          url,
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    final parsed = _decode(res);
    print('[PROFILE PATCH] ${res.statusCode} -> $parsed');

    if (_isOk(res.statusCode)) {
      return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
    }

    return {
      'success': false,
      'message': _extractMessage(parsed) ?? 'Update failed (${res.statusCode})',
      'data': parsed,
      'statusCode': res.statusCode,
    };
  } on TimeoutException {
    return {'success': false, 'message': 'Request timed out'};
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }
}


  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/auth/change-password');

    try {
      final res = await http
          .put(
            url,
            headers: await _authHeaders(),
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[PASSWORD PUT] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Password change failed (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/auth/profile');

    try {
      final res = await http
          .delete(
            url,
            headers: await _authHeadersNoContentType(),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[DELETE ACCOUNT] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to delete account',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ======================
  // VENUES  ✅ FIXED (AUTH HEADER ADDED)
  // ======================

  static Future<Map<String, dynamic>> fetchVenues({String? search}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not authorized, no token'};
    }

    final query = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';

    final url = Uri.parse('$baseUrl/api/venues$query');

    try {
      print('[VENUES] GET $url');

      final res = await http
          .get(
            url,
            headers: await _authHeadersNoContentType(), // ✅ NOW ATTACHES TOKEN
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[VENUES] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        // normalize list outputs
        if (parsed is Map && parsed['venues'] is List) return {'success': true, 'data': parsed['venues']};
        if (parsed is Map && parsed['data'] is List) return {'success': true, 'data': parsed['data']};
        if (parsed is List) return {'success': true, 'data': parsed};
        return {'success': true, 'data': <dynamic>[]};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to load venues (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ======================
  // BOOKINGS
  // ======================

  static Future<Map<String, dynamic>> createBooking({
    required String venueId,
    required String branchId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/bookings');

    try {
      final res = await http
          .post(
            url,
            headers: await _authHeaders(),
            body: jsonEncode({
              'venueId': venueId,
              'branchId': branchId,
              'title': title,
              'scheduledAt': scheduledAt.toIso8601String(),
            }),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[BOOKING POST] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Booking failed (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchMyTodayBooking({required String branchId}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/bookings/me/today?branchId=${Uri.encodeComponent(branchId)}');

    try {
      final res = await http
          .get(
            url,
            headers: await _authHeadersNoContentType(),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[BOOKING TODAY] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to load today booking (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchMyBookings() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/bookings/me');

    try {
      final res = await http
          .get(
            url,
            headers: await _authHeadersNoContentType(),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[BOOKINGS ME] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        if (parsed is Map && parsed['data'] is List) return {'success': true, 'data': parsed['data']};
        if (parsed is List) return {'success': true, 'data': parsed};
        if (parsed is Map && parsed['success'] == true && parsed['data'] == null) {
          return {'success': true, 'data': <dynamic>[]};
        }
        return {'success': true, 'data': <dynamic>[]};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to load bookings (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> fetchBookingById(String bookingId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/bookings/$bookingId');

    try {
      final res = await http
          .get(
            url,
            headers: await _authHeadersNoContentType(),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[BOOKING BY ID] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitBookingReview({
    required String bookingId,
    required int rating,
    required String review,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/bookings/$bookingId/review');

    try {
      final res = await http
          .post(
            url,
            headers: await _authHeaders(),
            body: jsonEncode({'rating': rating, 'review': review}),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[BOOKING REVIEW] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to submit review',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // ======================
  // REAL-TIME QUEUE
  // ======================

  static Future<Map<String, dynamic>> fetchLiveQueue({required String branchId}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return {'success': false, 'message': 'Not logged in'};

    final url = Uri.parse('$baseUrl/api/queue/live/$branchId');

    try {
      final res = await http
          .get(
            url,
            headers: await _authHeadersNoContentType(),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      print('[LIVE QUEUE] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': _unwrapData(parsed), 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ?? 'Failed to load live queue',
        'data': parsed,
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

  static dynamic _decode(http.Response res) {
    final body = res.body;
    if (body.isEmpty) return {'message': 'Empty response from server'};
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static dynamic _unwrapData(dynamic parsed) {
    if (parsed is Map && parsed.containsKey('data')) return parsed['data'];
    return parsed;
  }

  static String? _extractMessage(dynamic parsed) {
    if (parsed is Map && parsed['message'] != null) return parsed['message'].toString();
    if (parsed is Map && parsed['error'] != null) return parsed['error'].toString();
    if (parsed is Map && parsed['data'] is Map && (parsed['data'] as Map)['message'] != null) {
      return (parsed['data'] as Map)['message'].toString();
    }
    if (parsed is String && parsed.isNotEmpty) return parsed;
    return null;
  }

  static String? _extractToken(dynamic parsed) {
    if (parsed is Map && parsed['token'] is String) {
      final t = (parsed['token'] as String).trim();
      return t.isEmpty ? null : t;
    }
    if (parsed is Map && parsed['data'] is Map && (parsed['data'] as Map)['token'] is String) {
      final t = ((parsed['data'] as Map)['token'] as String).trim();
      return t.isEmpty ? null : t;
    }
    if (parsed is Map &&
        parsed['data'] is Map &&
        (parsed['data'] as Map)['data'] is Map &&
        ((parsed['data'] as Map)['data'] as Map)['token'] is String) {
      final t = (((parsed['data'] as Map)['data'] as Map)['token'] as String).trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
}
