import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking_history_item.dart';

class BookingHistoryStorage {
  static const String _key = 'booking_history_items';

  static Future<List<BookingHistoryItem>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final items = decoded
          .whereType<Map>()
          .map((e) => BookingHistoryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return items;
    } catch (_) {
      // Corrupt cache → clear it to avoid repeated crashes
      await prefs.remove(_key);
      return [];
    }
  }

  static Future<void> saveAll(List<BookingHistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();

    // sort newest first
    final sorted = [...items]..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final raw = jsonEncode(sorted.map((e) => e.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  static Future<void> addOrUpdate(BookingHistoryItem item) async {
    final items = await getAll();

    final idx = items.indexWhere((x) => x.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }

    await saveAll(items);
  }

  /// Use this after GET /api/bookings/me to cache the server as source of truth.
  static Future<void> replaceAllFromApi(List<BookingHistoryItem> apiItems) async {
    await saveAll(apiItems);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
