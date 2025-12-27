import 'package:queless_app/data/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/api_client.dart';
import '../../data/services/api_service.dart'; // <-- this must match your real path

class BookingService {
  final ApiClient _api = ApiClient();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<Map<String, dynamic>> createBooking({
    required String venueId,
    required String title,
    required DateTime scheduledAt,
  }) async {
    final token = await _getToken();
    if (token == null) {
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

  Future<Map<String, dynamic>> getMyBookings() async {
    final token = await _getToken();
    if (token == null) {
      return {'statusCode': 401, 'data': {'message': 'No token'}};
    }

    final url = '${ApiService.baseUrl}/api/bookings/me';

    return _api.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
