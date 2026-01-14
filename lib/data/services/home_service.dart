import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class HomeService {
  static const Duration _timeout = Duration(seconds: 12);

  /// Fetch my bookings (used for Home stats + "Active booking card")
  static Future<Map<String, dynamic>> fetchMyBookings() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) {
      return {'success': false, 'message': 'Not logged in'};
    }

    final url = Uri.parse('${ApiService.baseUrl}/api/bookings/me');

    try {
      final res = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);

      dynamic parsed;
      try {
        parsed = jsonDecode(res.body);
      } catch (_) {
        parsed = res.body;
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // supports:
        // 1) { bookings: [...] }
        // 2) { data: [...] }
        // 3) [ ... ]
        if (parsed is Map && parsed['bookings'] is List) {
          return {'success': true, 'data': parsed['bookings']};
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
        'message': (parsed is Map && parsed['message'] != null)
            ? parsed['message'].toString()
            : 'Failed to load bookings (${res.statusCode})',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
