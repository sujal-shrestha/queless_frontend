import 'package:flutter/material.dart';
import '../data/models/venue_model.dart';
import '../data/services/venue_service.dart';

class VenueViewModel extends ChangeNotifier {
  final VenueService _service = VenueService();

  bool isLoading = false;
  String? error;
  List<VenueModel> venues = [];

  Future<void> loadVenues({String search = ''}) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      venues = await _service.fetchVenues(search: search);
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
