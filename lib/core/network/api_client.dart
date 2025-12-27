import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final Duration timeout;

  ApiClient({this.timeout = const Duration(seconds: 20)});

  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: _defaultHeaders(headers))
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error', 'error': e.toString()},
      };
    }
  }

  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: _defaultHeaders(headers),
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error', 'error': e.toString()},
      };
    }
  }

  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: _defaultHeaders(headers),
            body: jsonEncode(body ?? {}),
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error', 'error': e.toString()},
      };
    }
  }

  Future<Map<String, dynamic>> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .delete(Uri.parse(url), headers: _defaultHeaders(headers))
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error', 'error': e.toString()},
      };
    }
  }

  Map<String, String> _defaultHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return {
        'statusCode': response.statusCode,
        'data': {},
      };
    }

    try {
      final decoded = jsonDecode(body);
      return {
        'statusCode': response.statusCode,
        'data': decoded,
      };
    } catch (_) {
      return {
        'statusCode': response.statusCode,
        'data': {
          'message': 'Non-JSON response from server',
          'raw': response.body,
        },
      };
    }
  }
}
