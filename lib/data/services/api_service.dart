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

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[SIGNUP] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = _extractToken(parsed);
        if (token != null) await _saveToken(token);

        return {
          'success': true,
          'data': parsed,
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
      return {
        'success': false,
        'message': 'Request timed out. Is the server running on 5001?',
      };
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

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[LOGIN] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final token = _extractToken(parsed);
        if (token != null) await _saveToken(token);

        return {
          'success': true,
          'data': parsed,
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
      return {
        'success': false,
        'message': 'Request timed out. Is the server running on 5001?',
      };
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
    // ignore: avoid_print
    print('[TOKEN] Saved token len=${token.length}');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    // ignore: avoid_print
    print('[TOKEN] Read token? ${t != null && t.isNotEmpty}');
    return t;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    // ignore: avoid_print
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

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[PROFILE GET] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final data = _extractUser(parsed) ?? parsed;
        return {
          'success': true,
          'data': data,
          'statusCode': res.statusCode,
        };
      }

      return {
        'success': false,
        'message':
            _extractMessage(parsed) ?? 'Failed to load profile (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// ✅ Update profile (supports phone + address)
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    String? phone,
    String? address,
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
              'address': address ?? '',
            }),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[PROFILE PATCH] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final data = _extractUser(parsed) ?? parsed;
        return {
          'success': true,
          'data': data,
          'statusCode': res.statusCode,
        };
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

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[PASSWORD PUT] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {
          'success': true,
          'data': parsed,
          'statusCode': res.statusCode,
        };
      }

      return {
        'success': false,
        'message':
            _extractMessage(parsed) ?? 'Password change failed (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// ✅ Delete account
  static Future<Map<String, dynamic>> deleteAccount() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/auth/profile');

    try {
      final res = await http
          .delete(
            url,
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[DELETE ACCOUNT] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': parsed, 'statusCode': res.statusCode};
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
  // VENUES
  // ======================

  static Future<Map<String, dynamic>> fetchVenues({String? search}) async {
    final query = (search != null && search.trim().isNotEmpty)
        ? '?search=${Uri.encodeComponent(search.trim())}'
        : '';

    final url = Uri.parse('$baseUrl/api/venues$query');

    try {
      // ignore: avoid_print
      print('[VENUES] GET $url');

      final res = await http
          .get(
            url,
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[VENUES] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        if (parsed is Map && parsed['venues'] is List) {
          return {'success': true, 'data': parsed['venues']};
        }
        if (parsed is Map && parsed['data'] is List) {
          return {'success': true, 'data': parsed['data']};
        }
        if (parsed is List) {
          return {'success': true, 'data': parsed};
        }
        return {'success': true, 'data': <dynamic>[]};
      }

      return {
        'success': false,
        'message':
            _extractMessage(parsed) ?? 'Failed to load venues (${res.statusCode})',
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

  /// ✅ Backend requires: venueId, branchId, title, scheduledAt
  static Future<Map<String, dynamic>> createBooking({
    required String venueId,
    required String branchId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/bookings');

    try {
      final res = await http
          .post(
            url,
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'venueId': venueId,
              'branchId': branchId,
              'title': title,
              'scheduledAt': scheduledAt.toIso8601String(),
            }),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[BOOKING POST] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': parsed, 'statusCode': res.statusCode};
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

  /// ✅ Live Queue screen uses this
  /// GET /api/bookings/me/today?branchId=...
  static Future<Map<String, dynamic>> fetchMyTodayBooking({
    required String branchId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse(
      '$baseUrl/api/bookings/me/today?branchId=${Uri.encodeComponent(branchId)}',
    );

    try {
      final res = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[BOOKING TODAY] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': parsed, 'statusCode': res.statusCode};
      }

      return {
        'success': false,
        'message': _extractMessage(parsed) ??
            'Failed to load today booking (${res.statusCode})',
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
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/bookings/me');

    try {
      final res = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[BOOKINGS ME] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        if (parsed is Map && parsed['data'] is List) {
          return {'success': true, 'data': parsed['data']};
        }
        if (parsed is List) return {'success': true, 'data': parsed};
        return {'success': true, 'data': <dynamic>[]};
      }

      return {
        'success': false,
        'message':
            _extractMessage(parsed) ?? 'Failed to load bookings (${res.statusCode})',
        'data': parsed,
        'statusCode': res.statusCode,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// ✅ Fetch booking by id (for QR ticket in history upcoming)
  static Future<Map<String, dynamic>> fetchBookingById(String bookingId) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('$baseUrl/api/bookings/$bookingId');

    try {
      final res = await http
          .get(
            url,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[BOOKING BY ID] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        final data = (parsed is Map && parsed['data'] is Map) ? parsed['data'] : parsed;
        return {'success': true, 'data': data, 'statusCode': res.statusCode};
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

  /// ✅ Submit review for past booking
  static Future<Map<String, dynamic>> submitBookingReview({
    required String bookingId,
    required int rating,
    required String review,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    // Option: POST /api/bookings/:id/review
    final url = Uri.parse('$baseUrl/api/bookings/$bookingId/review');

    try {
      final res = await http
          .post(
            url,
            headers: {
              ..._headers,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'rating': rating,
              'review': review,
            }),
          )
          .timeout(_timeout);

      final parsed = _decode(res);
      // ignore: avoid_print
      print('[BOOKING REVIEW] ${res.statusCode} -> $parsed');

      if (_isOk(res.statusCode)) {
        return {'success': true, 'data': parsed, 'statusCode': res.statusCode};
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

  static String? _extractMessage(dynamic parsed) {
    if (parsed is Map && parsed['message'] != null) return parsed['message'].toString();

    if (parsed is Map && parsed['data'] is Map && (parsed['data'] as Map)['message'] != null) {
      return (parsed['data'] as Map)['message'].toString();
    }

    if (parsed is Map && parsed['error'] != null) return parsed['error'].toString();

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

  static Map<String, dynamic>? _extractUser(dynamic parsed) {
    // { user: {...} }
    if (parsed is Map && parsed['user'] is Map) {
      return Map<String, dynamic>.from(parsed['user'] as Map);
    }

    // { data: { user: {...} } OR { data: {...} }
    if (parsed is Map && parsed['data'] is Map) {
      final data = parsed['data'] as Map;
      if (data['user'] is Map) return Map<String, dynamic>.from(data['user'] as Map);
      return Map<String, dynamic>.from(data);
    }

    if (parsed is Map) return Map<String, dynamic>.from(parsed);
    return null;
  }
}
