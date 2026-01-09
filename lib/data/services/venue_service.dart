// lib/data/services/venue_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue_model.dart';

class VenueService {
  static const String baseUrl = 'http://10.0.2.2:5001'; // emulator -> backend

  Future<List<VenueModel>> fetchVenues({String search = ''}) async {
    final uri = Uri.parse('$baseUrl/api/venues')
        .replace(queryParameters: search.trim().isEmpty ? null : {'search': search.trim()});

    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
    });

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Failed: ${res.statusCode} ${res.body}');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! List) throw Exception('Invalid response');

    return decoded.map((e) => VenueModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
