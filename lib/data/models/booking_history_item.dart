// lib/data/models/booking_history_item.dart

class BookingHistoryItem {
  final String id;
  final String title;
  final String organizationName;
  final DateTime dateTime;
  final String status; // upcoming | completed | cancelled

  // Optional fields
  final String ticketToken;
  final String queueNumber;
  final String branchName;

  // ✅ Helpful for debugging (optional)
  final bool hasValidDate;

  const BookingHistoryItem({
    required this.id,
    required this.title,
    required this.organizationName,
    required this.dateTime,
    required this.status,
    this.ticketToken = "",
    this.queueNumber = "",
    this.branchName = "",
    this.hasValidDate = true,
  });

  factory BookingHistoryItem.fromJson(Map<String, dynamic> json) {
    final id = (json['_id'] ?? json['id'] ?? '').toString();
    final title = (json['title'] ?? '').toString();

    // Organization name fallback
    String org = (json['organizationName'] ?? '').toString();
    if (org.trim().isEmpty) {
      final venue = json['venue'];
      if (venue is Map && venue['name'] != null) {
        org = venue['name'].toString();
      }
    }
    if (org.trim().isEmpty) org = "—";

    // ✅ Prefer real booking time fields first
    final rawDate =
        json['dateTime'] ??
        json['scheduledAt'] ??
        json['scheduledDate'] ??
        json['bookingDate'] ??
        json['date'] ??
        json['startTime'] ??
        json['time'] ??
        json['slotTime'] ??
        json['createdAt']; // keep last (not ideal but better than null)

    final parsed = _parseAnyDate(rawDate);

    // ✅ If missing/invalid date, DON'T silently use now (it breaks sorting & expiry logic)
    final safeDate = parsed ?? DateTime.fromMillisecondsSinceEpoch(0);

    final status = (json['status'] ?? 'upcoming').toString();

    return BookingHistoryItem(
      id: id,
      title: title,
      organizationName: org,
      dateTime: safeDate,
      status: status,
      hasValidDate: parsed != null,
      ticketToken: (json['ticketToken'] ?? '').toString(),
      queueNumber: (json['queueNumber'] ?? '').toString(),
      branchName: (json['branchName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'organizationName': organizationName,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'ticketToken': ticketToken,
      'queueNumber': queueNumber,
      'branchName': branchName,
      'hasValidDate': hasValidDate,
    };
  }

  static DateTime? _parseAnyDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

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

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // sometimes: "YYYY-MM-DD HH:mm:ss"
    final cleaned = s.replaceAll(' ', 'T');
    return DateTime.tryParse(cleaned);
  }
}
