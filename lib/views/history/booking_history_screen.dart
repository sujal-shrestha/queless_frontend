import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../viewmodels/booking_history_viewmodel.dart';
import '../../data/models/booking_history_item.dart';
import '../../data/services/api_service.dart';


class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  static const Color kGreen = Color(0xFF65BF61);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<BookingHistoryViewModel>().loadHistory());
  }

  // =========================
  // ✅ TICKET CAPTURE / SHARE / SAVE (reused)
  // =========================
  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return null;

      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToGallery(GlobalKey key) async {
    final bytes = await _capturePng(key);
    if (bytes == null) {
      _snack("Failed to capture ticket image");
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ticket_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes, flush: true);

    final ok = await GallerySaver.saveImage(file.path);
    _snack(ok == true ? "Ticket saved to Gallery ✅" : "Failed to save ticket");
  }

  Future<void> _share(GlobalKey key) async {
    final bytes = await _capturePng(key);
    if (bytes == null) {
      _snack("Failed to capture ticket image");
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ticket_share.png');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "My QueueLess Ticket (show this QR at the counter)",
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // =========================
  // ✅ UPCOMING: Show QR + Save/Share
  // =========================
  Future<void> _openUpcomingTicket(BookingHistoryItem item) async {
    // If your list endpoint doesn’t include ticketToken, you can fetch details here by bookingId.
    // For now we’ll try from item.ticketToken first:
    String token = item.ticketToken;

    // ✅ Optional: If token missing, try fetching booking details
    if (token.trim().isEmpty) {
      try {
        final res = await ApiService.fetchBookingById(item.id); // we’ll add this below
        if (res['success'] == true) {
          final data = res['data'];
          if (data is Map && data['ticketToken'] != null) {
            token = data['ticketToken'].toString();
          }
        }
      } catch (_) {}
    }

    if (token.trim().isEmpty) {
      _snack("Ticket QR not available for this booking.");
      return;
    }

    final key = GlobalKey();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final bottomPad = 20 + MediaQuery.of(context).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 14),

              RepaintBoundary(
                key: key,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kGreen.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2, color: kGreen, size: 44),
                      const SizedBox(height: 8),
                      const Text("Your Ticket", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),

                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(
                          data: token,
                          version: QrVersions.auto,
                          size: 220,
                        ),
                      ),

                      const SizedBox(height: 12),
                      Text(item.organizationName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(_formatDateTime(item.dateTime), style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                      if (item.queueNumber.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text("Queue: ${item.queueNumber}", style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _share(key),
                      icon: const Icon(Icons.share),
                      label: const Text("Share"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                      onPressed: () => _saveToGallery(key),
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text("Save", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================
  // ✅ PAST: Rate + Review
  // =========================
  Future<void> _openPastReview(BookingHistoryItem item) async {
    int rating = 0;
    final controller = TextEditingController();
    bool sending = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF6F8FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final bottomPad = 20 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

        return StatefulBuilder(
          builder: (context, setSheet) {
            Future<void> submit() async {
              if (rating == 0) {
                _snack("Please select a star rating first.");
                return;
              }
              setSheet(() => sending = true);

              final res = await ApiService.submitBookingReview(
                bookingId: item.id,
                rating: rating,
                review: controller.text.trim(),
              );

              setSheet(() => sending = false);

              if (res['success'] == true) {
                Navigator.pop(context);
                _snack("Thanks! Review submitted ✅");
              } else {
                _snack((res['message'] ?? "Failed to submit review").toString());
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),
                  ),
                  const SizedBox(height: 14),
                  Text(item.organizationName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(_formatDateTime(item.dateTime), style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),

                  const Text("Rate your experience", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),

                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      final filled = star <= rating;
                      return IconButton(
                        onPressed: () => setSheet(() => rating = star),
                        icon: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: kGreen,
                          size: 34,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 8),
                  const Text("Write a review (optional)", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),

                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Tell us what went well…",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kGreen, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                      onPressed: sending ? null : submit,
                      child: sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : const Text("Submit Review", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BookingHistoryViewModel>();
    final primary = Theme.of(context).primaryColor;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Booking History",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatChip(label: "Past", value: vm.past.length.toString()),
                        const SizedBox(width: 10),
                        _StatChip(label: "Upcoming", value: vm.upcoming.length.toString()),
                        const Spacer(),
                        IconButton(
                          onPressed: vm.loading ? null : () => vm.loadHistory(),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                      child: const TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black54,
                        dividerColor: Colors.transparent,
                        tabs: [Tab(text: "Past Visits"), Tab(text: "Upcoming")],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (_) {
                    if (vm.loading) return const Center(child: CircularProgressIndicator());
                    if (vm.error != null) return Center(child: Text(vm.error!));

                    return TabBarView(
                      children: [
                        _HistoryList(
                          items: vm.past,
                          emptyText: "No past visits yet.",
                          onTap: (item) => _openPastReview(item),
                        ),
                        _HistoryList(
                          items: vm.upcoming,
                          emptyText: "No upcoming bookings.",
                          onTap: (item) => _openUpcomingTicket(item),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<BookingHistoryItem> items;
  final String emptyText;
  final void Function(BookingHistoryItem item) onTap;

  const _HistoryList({
    required this.items,
    required this.emptyText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyText));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _HistoryCard(item: items[i], onTap: () => onTap(items[i])),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final BookingHistoryItem item;
  final VoidCallback onTap;

  const _HistoryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = item.status.toLowerCase();
    final badge = _badgeStyle(status);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badge.bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badge.fg)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.organizationName, style: const TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 8),
                Text(_formatDateTime(item.dateTime), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

({Color bg, Color fg}) _badgeStyle(String status) {
  switch (status) {
    case "upcoming":
      return (bg: const Color(0x1AFFC107), fg: const Color(0xFF8D6E00));
    case "completed":
      return (bg: const Color(0x1A4CAF50), fg: const Color(0xFF2E7D32));
    case "cancelled":
    case "canceled":
      return (bg: const Color(0x1AF44336), fg: const Color(0xFFC62828));
    default:
      return (bg: const Color(0x1A9E9E9E), fg: const Color(0xFF616161));
  }
}

String _formatDateTime(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, "0");
  int hour = dt.hour;
  final min = two(dt.minute);
  final ampm = hour >= 12 ? "PM" : "AM";
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return "${dt.year}-${two(dt.month)}-${two(dt.day)} • $hour:$min $ampm";
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
