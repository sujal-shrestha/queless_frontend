import 'package:flutter/foundation.dart';
import '../data/models/booking_history_item.dart';
import '../data/services/booking_service.dart';

class BookingHistoryViewModel extends ChangeNotifier {
  final BookingService _service = BookingService();

  bool _loading = false;
  String? _error;

  List<BookingHistoryItem> _past = [];
  List<BookingHistoryItem> _upcoming = [];

  bool get loading => _loading;
  String? get error => _error;
  List<BookingHistoryItem> get past => _past;
  List<BookingHistoryItem> get upcoming => _upcoming;

  Future<void> loadHistory() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _service.getMyBookings();
      final status = res['statusCode'] as int;
      final data = res['data'];

      if (status < 200 || status >= 300) {
        _error = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to load history';
        _past = [];
        _upcoming = [];
        return;
      }

      final itemsJson = (data is Map ? data['items'] : null);
      if (itemsJson is! List) {
        _error = 'Invalid response format';
        _past = [];
        _upcoming = [];
        return;
      }

      final items = itemsJson
          .map((e) => BookingHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final past = <BookingHistoryItem>[];
      final upcoming = <BookingHistoryItem>[];

      for (final item in items) {
        if (item.status.toLowerCase() == 'completed') {
          past.add(item);
        } else {
          upcoming.add(item);
        }
      }

      past.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      _past = past;
      _upcoming = upcoming;
    } catch (e) {
      _error = e.toString();
      _past = [];
      _upcoming = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
