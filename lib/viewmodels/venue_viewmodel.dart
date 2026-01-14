import 'package:flutter/material.dart';

import '../data/models/venue_model.dart';
import '../data/services/venue_service.dart';

class VenueViewModel extends ChangeNotifier {
  VenueViewModel() {
    debugPrint('[VenueVM] CONSTRUCTED');
  }
  bool isLoading = false;
  String? error;
  List<VenueModel> venues = [];

  Future<void> loadVenues({String? search}) async {
    // ignore: avoid_print
    print('[VenueVM] loadVenues(search="$search")');

    isLoading = true;
    error = null;
    notifyListeners();

    final res = await VenueService.fetchVenues(search: search);

    isLoading = false;

    if (res['success'] == true) {
      final raw = res['data'];

      final list = (raw is List) ? raw : <dynamic>[];

      venues = list
          .where((e) => e is Map)
          .map((e) => VenueModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // ignore: avoid_print
      print('[VenueVM] venues.length=${venues.length}');

      notifyListeners();
      return;
    }

    venues = [];
    error = (res['message'] ?? 'Failed to load venues').toString();
    // ignore: avoid_print
    print('[VenueVM] ERROR=$error');

    notifyListeners();
  }
}
