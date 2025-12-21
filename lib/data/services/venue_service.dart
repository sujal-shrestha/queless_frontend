import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/venue_model.dart';

class VenueService {
  final ApiClient _client = ApiClient();

  Future<List<VenueModel>> fetchVenues({String search = ''}) async {
    final q = search.trim();
    final url = q.isEmpty
        ? '${ApiConstants.baseUrl}/api/venues'
        : '${ApiConstants.baseUrl}/api/venues?search=$q';

    final data = await _client.get(url);

    final list = (data['venues'] as List? ?? []);
    return list.map((e) => VenueModel.fromJson(e)).toList();
  }
}
