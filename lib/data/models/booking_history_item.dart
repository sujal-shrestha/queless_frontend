// lib/data/models/booking_history_item.dart

class BookingHistoryItem {
  final String id;
  final String title;
  final String organizationName;
  final DateTime dateTime;
  final String status; // upcoming | completed | cancelled

  // Optional fields (won’t break old cache)
  final String ticketToken;
  final String queueNumber;
  final String branchName;

  const BookingHistoryItem({
    required this.id,
    required this.title,
    required this.organizationName,
    required this.dateTime,
    required this.status,
    this.ticketToken = "",
    this.queueNumber = "",
    this.branchName = "",
  });

  factory BookingHistoryItem.fromJson(Map<String, dynamic> json) {
    // ✅ backend usually uses _id; cache uses id
    final id = (json['_id'] ?? json['id'] ?? '').toString();

    final title = (json['title'] ?? '').toString();

    // ✅ organizationName might be missing; try venue.name
    String org = (json['organizationName'] ?? '').toString();
    if (org.trim().isEmpty) {
      final venue = json['venue'];
      if (venue is Map && venue['name'] != null) {
        org = venue['name'].toString();
      }
    }
    if (org.trim().isEmpty) org = "—";

    // ✅ accept BOTH cache key "dateTime" and API keys like "scheduledAt"
    final dt = _parseAnyDate(
          json['dateTime'] ??
              json['scheduledAt'] ??
              json['createdAt'] ??
              json['updatedAt'],
        ) ??
        DateTime.now();

    final status = (json['status'] ?? 'upcoming').toString();

    return BookingHistoryItem(
      id: id,
      title: title,
      organizationName: org,
      dateTime: dt,
      status: status,
      ticketToken: (json['ticketToken'] ?? '').toString(),
      queueNumber: (json['queueNumber'] ?? '').toString(),
      branchName: (json['branchName'] ?? '').toString(),
    );
  }

  /// ✅ this is what we store in SharedPreferences
  Map<String, dynamic> toJson() {
    return {
      'id': id, // cache stores id (not _id) to keep it clean
      'title': title,
      'organizationName': organizationName,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'ticketToken': ticketToken,
      'queueNumber': queueNumber,
      'branchName': branchName,
    };
  }

  /// ✅ very flexible date parser (prevents "FormatException: Invalid date format")
  static DateTime? _parseAnyDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    // unix timestamp support
    if (value is int) {
      // milliseconds
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      // seconds
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }

    final s = value.toString().trim();
    if (s.isEmpty) return null;

    // ISO parse
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // sometimes comes like "YYYY-MM-DD HH:mm:ss"
    final cleaned = s.replaceAll(' ', 'T');
    return DateTime.tryParse(cleaned);
  }
}
