class BookingHistoryItem {
  final String id;
  final String title;
  final String organizationName;
  final DateTime dateTime;
  final String status; // upcoming | completed | cancelled

  const BookingHistoryItem({
    required this.id,
    required this.title,
    required this.organizationName,
    required this.dateTime,
    required this.status,
  });

  factory BookingHistoryItem.fromJson(Map<String, dynamic> json) {
    return BookingHistoryItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      organizationName: (json['organizationName'] ?? '').toString(),
      dateTime: DateTime.parse((json['dateTime'] ?? '').toString()),
      status: (json['status'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'organizationName': organizationName,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
    };
  }
}
