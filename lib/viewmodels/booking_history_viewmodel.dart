// lib/viewmodels/booking_history_viewmodel.dart
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

  bool _isExpired(DateTime dt) {
    // ✅ Past if booking time has already passed
    return dt.isBefore(DateTime.now());
  }

  bool _isPastStatus(String status) {
    final s = status.toLowerCase().trim();
    return (s == 'completed' || s == 'cancelled' || s == 'canceled');
  }

  Future<void> loadHistory() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _service.getMyBookings();

      // ✅ Your service returns: { statusCode, data }
      final status = (res['statusCode'] is int) ? res['statusCode'] as int : 500;
      final data = res['data'];

      if (status < 200 || status >= 300) {
        _error = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : 'Failed to load history';
        _past = [];
        _upcoming = [];
        return;
      }

      // ✅ Extract list from multiple possible shapes
      final itemsJson = _extractList(data);
      if (itemsJson == null) {
        _error = 'Invalid response format';
        _past = [];
        _upcoming = [];
        return;
      }

      final items = itemsJson
          .where((e) => e is Map)
          .map((e) => BookingHistoryItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();

      final past = <BookingHistoryItem>[];
      final upcoming = <BookingHistoryItem>[];

      for (final item in items) {
        // ✅ Decide using BOTH:
        // 1) Date expired -> past
        // 2) Backend status says completed/cancelled -> past
        final isPast = _isExpired(item.dateTime) || _isPastStatus(item.status);

        if (isPast) {
          past.add(item);
        } else {
          upcoming.add(item);
        }
      }

      // ✅ Sorting
      past.sort((a, b) => b.dateTime.compareTo(a.dateTime)); // newest past first
      upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime)); // soonest upcoming first

      _past = past;
      _upcoming = upcoming;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _past = [];
      _upcoming = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // =========================
  // Helpers
  // =========================

  List<dynamic>? _extractList(dynamic data) {
    // if service already returns List
    if (data is List) return data;

    if (data is Map) {
      // ✅ if backend returns { data: [...] }
      if (data['data'] is List) return data['data'];

      // ✅ if backend returns { success:true, data:[...] }
      if (data['success'] == true && data['data'] is List) return data['data'];

      // ✅ if backend returns { bookings:[...] }
      if (data['bookings'] is List) return data['bookings'];

      // nested forms
      final d1 = data['data'];
      if (d1 is Map) {
        if (d1['items'] is List) return d1['items'];
        if (d1['data'] is List) return d1['data'];
        if (d1['bookings'] is List) return d1['bookings'];
      }
    }

    return null;
  }
}
