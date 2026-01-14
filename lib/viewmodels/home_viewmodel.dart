import 'package:flutter/material.dart';
import '../data/services/home_service.dart';

class HomeViewModel extends ChangeNotifier {
  bool isLoading = false;
  String? error;

  int appointmentsCount = 0;

  // Active booking card data (safe defaults)
  String activeTitle = 'No active booking';
  String activeSubtitle = 'Book an appointment to get started';
  String activeDateText = '';
  String activeTimeText = '';
  String queueNumber = '--';
  String peopleAhead = '--';
  String estWait = '--';

  Future<void> loadHome() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final res = await HomeService.fetchMyBookings();

    isLoading = false;

    if (res['success'] == true) {
      final data = res['data'];
      final list = (data is List) ? data : <dynamic>[];

      appointmentsCount = list.length;

      // Pick “active” booking: choose first, or nearest upcoming if date exists
      Map<String, dynamic>? active;

      DateTime? bestDate;
      for (final item in list) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item as Map);
        final dt = _extractBookingDateTime(m);
        if (dt == null) {
          active ??= m;
          continue;
        }

        if (bestDate == null) {
          bestDate = dt;
          active = m;
        } else {
          // choose closest future; fallback closest overall
          final now = DateTime.now();
          final currentIsFuture = bestDate!.isAfter(now);
          final candidateIsFuture = dt.isAfter(now);

          if (!currentIsFuture && candidateIsFuture) {
            bestDate = dt;
            active = m;
          } else if (candidateIsFuture == currentIsFuture) {
            if ((dt.difference(now)).abs() < (bestDate!.difference(now)).abs()) {
              bestDate = dt;
              active = m;
            }
          }
        }
      }

      if (active == null) {
        _setEmpty();
        notifyListeners();
        return;
      }

      // These keys are “best guess” — your backend can be slightly different.
      // We keep fallbacks so UI never crashes.
      final venueName = (active['venueName'] ??
              active['venue']?['name'] ??
              active['organizationName'] ??
              active['venue'] ??
              '')
          .toString()
          .trim();

      final serviceName = (active['serviceName'] ?? active['service'] ?? '').toString().trim();

      activeTitle = venueName.isNotEmpty ? venueName : 'Your Appointment';
      activeSubtitle = serviceName.isNotEmpty ? serviceName : 'Booking confirmed';

      final dt = _extractBookingDateTime(active);
      if (dt != null) {
        activeDateText = _formatDate(dt);
        activeTimeText = _formatTime(dt);
      } else {
        activeDateText = '';
        activeTimeText = '';
      }

      queueNumber = (active['queueNumber'] ?? active['queueNo'] ?? active['tokenNo'] ?? '--').toString();
      peopleAhead = (active['peopleAhead'] ?? active['ahead'] ?? '--').toString();
      estWait = (active['estimatedWait'] ?? active['estWait'] ?? '--').toString();

      notifyListeners();
      return;
    }

    _setEmpty();
    error = (res['message'] ?? 'Failed to load home').toString();
    notifyListeners();
  }

  void _setEmpty() {
    appointmentsCount = 0;
    activeTitle = 'No active booking';
    activeSubtitle = 'Book an appointment to get started';
    activeDateText = '';
    activeTimeText = '';
    queueNumber = '--';
    peopleAhead = '--';
    estWait = '--';
  }

  DateTime? _extractBookingDateTime(Map<String, dynamic> m) {
    // support keys like: date, datetime, startTime, bookedAt...
    final raw = m['dateTime'] ?? m['datetime'] ?? m['date'] ?? m['startTime'] ?? m['bookedAt'];
    if (raw == null) return null;

    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatDate(DateTime dt) {
    // simple, no intl dependency
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(DateTime dt) {
    int h = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$min $ampm';
  }
}
