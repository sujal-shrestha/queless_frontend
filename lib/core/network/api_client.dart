import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  // =========================
  // GET REQUEST
  // =========================
  Future<Map<String, dynamic>> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: _defaultHeaders(headers),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error'},
      };
    }
  }

  // =========================
  // POST REQUEST
  // =========================
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _defaultHeaders(headers),
        body: jsonEncode(body ?? {}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error'},
      };
    }
  }

  // =========================
  // PUT REQUEST
  // =========================
  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.put(
        Uri.parse(url),
        headers: _defaultHeaders(headers),
        body: jsonEncode(body ?? {}),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error'},
      };
    }
  }

  // =========================
  // DELETE REQUEST
  // =========================
  Future<Map<String, dynamic>> delete(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse(url),
        headers: _defaultHeaders(headers),
      );

      return _handleResponse(response);
    } catch (e) {
      return {
        'statusCode': 500,
        'data': {'message': 'Network error'},
      };
    }
  }

  // =========================
  // HELPERS
  // =========================
  Map<String, String> _defaultHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?headers,
    };
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      return {
        'statusCode': response.statusCode,
        'data': decoded,
      };
    } catch (_) {
      return {
        'statusCode': response.statusCode,
        'data': {'message': 'Invalid response from server'},
      };
    }
  }
}
