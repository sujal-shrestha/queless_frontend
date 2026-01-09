import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import 'api_service.dart';

class BookingService {
  final ApiClient _api = ApiClient();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // =========================
  // VENUES (Organizations)
  // GET /api/venues?search=
  // =========================
  Future<Map<String, dynamic>> getVenues({String search = ''}) async {
    final url = '${ApiService.baseUrl}/api/venues?search=$search';
    return _api.get(url);
  }

  // =========================
  // BRANCHES
  // GET /api/venues/:id/branches
  // =========================
  Future<Map<String, dynamic>> getBranches(String venueId) async {
    final url = '${ApiService.baseUrl}/api/venues/$venueId/branches';
    return _api.get(url);
  }

  // =========================
  // CREATE BOOKING (auth)
  // POST /api/bookings
  // =========================
  Future<Map<String, dynamic>> createBooking({
    required String venueId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return {'statusCode': 401, 'data': {'message': 'No token'}};
    }

    final url = '${ApiService.baseUrl}/api/bookings';

    return _api.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'venueId': venueId,
        'title': title,
        'scheduledAt': scheduledAt.toIso8601String(),
      },
    );
  }

  // =========================
  // MY BOOKINGS (auth)
  // GET /api/bookings/me
  // =========================
  Future<Map<String, dynamic>> getMyBookings() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return {'statusCode': 401, 'data': {'message': 'No token'}};
    }

    final url = '${ApiService.baseUrl}/api/bookings/me';

    return _api.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
