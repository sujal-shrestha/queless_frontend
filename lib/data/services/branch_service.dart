import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_service.dart';

class BranchService {
  static const Duration _timeout = Duration(seconds: 12);

  /// GET /api/venues/:venueId/branches
  /// Expected backend formats supported:
  /// 1) { "branches": [ ... ] }
  /// 2) { "data": [ ... ] }
  /// 3) [ ... ]
  static Future<Map<String, dynamic>> fetchBranches(String venueId) async {
    final url = Uri.parse('${ApiService.baseUrl}/api/venues/$venueId/branches');

    try {
      // ignore: avoid_print
      print('[BRANCHES] GET $url');

      final res = await http
          .get(
            url,
            headers: const {
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);

      // ignore: avoid_print
      print('[BRANCHES] status=${res.statusCode}');
      // ignore: avoid_print
      print('[BRANCHES] body=${res.body}');

      final parsed = _decode(res.body);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // ✅ supports: {branches: []}, {data: []}, or []
        if (parsed is Map && parsed['branches'] is List) {
          return {'success': true, 'data': parsed['branches']};
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
            : 'Failed to load branches (${res.statusCode})',
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return {'message': 'Empty response'};
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }
}
