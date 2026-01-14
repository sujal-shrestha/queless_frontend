class BookingDraft {
  final String venueId;
  final String venueName;
  final String? branchId;
  final String? branchName;
  final DateTime? date;
  final String? timeLabel;

  const BookingDraft({
    required this.venueId,
    required this.venueName,
    this.branchId,
    this.branchName,
    this.date,
    this.timeLabel,
  });

  BookingDraft copyWith({
    String? venueId,
    String? venueName,
    String? branchId,
    String? branchName,
    DateTime? date,
    String? timeLabel,
  }) {
    return BookingDraft(
      venueId: venueId ?? this.venueId,
      venueName: venueName ?? this.venueName,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      date: date ?? this.date,
      timeLabel: timeLabel ?? this.timeLabel,
    );
  }
}

class BookingConfirmedArgs {
  final String queueNumber;
  final String venueName;
  final String branchName;
  final DateTime date;
  final String timeLabel;

  // ✅ NEW: used for QR
  final String ticketToken;

  BookingConfirmedArgs({
    required this.queueNumber,
    required this.venueName,
    required this.branchName,
    required this.date,
    required this.timeLabel,
    required this.ticketToken,
  });
}
