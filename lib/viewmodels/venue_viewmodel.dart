import 'package:flutter/material.dart';

import '../data/models/venue_model.dart';
import '../data/services/api_service.dart'; // ✅ use ApiService (token)

class VenueViewModel extends ChangeNotifier {
  VenueViewModel() {
    debugPrint('[VenueVM] CONSTRUCTED');
  }

  bool isLoading = false;
  String? error;
  List<VenueModel> venues = [];

  Future<void> loadVenues({String? search}) async {
    print('[VenueVM] loadVenues(search="$search")');

    isLoading = true;
    error = null;
    notifyListeners();

    // ✅ IMPORTANT: use ApiService so token is included
    final res = await ApiService.fetchVenues(search: search);

    isLoading = false;

    if (res['success'] == true) {
      final raw = res['data'];
      final list = (raw is List) ? raw : <dynamic>[];

      venues = list
          .where((e) => e is Map)
          .map((e) => VenueModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      print('[VenueVM] venues.length=${venues.length}');
      notifyListeners();
      return;
    }

    venues = [];
    error = (res['message'] ?? 'Failed to load venues').toString();
    print('[VenueVM] ERROR=$error');
    notifyListeners();
  }
}
