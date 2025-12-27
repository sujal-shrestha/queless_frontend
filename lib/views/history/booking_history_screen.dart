import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/booking_history_viewmodel.dart';
import '../../data/models/booking_history_item.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<BookingHistoryViewModel>().loadHistory());
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
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black54,
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: "Past Visits"),
                          Tab(text: "Upcoming"),
                        ],
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
                        _HistoryList(items: vm.past, emptyText: "No past visits yet."),
                        _HistoryList(items: vm.upcoming, emptyText: "No upcoming bookings."),
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

  const _HistoryList({required this.items, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Text(emptyText));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _HistoryCard(item: items[i]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final BookingHistoryItem item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item.status.toLowerCase();
    final badge = _badgeStyle(status);

    return Container(
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
              Text(
                item.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badge.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.organizationName,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.black54),
              const SizedBox(width: 8),
              Text(
                _formatDateTime(item.dateTime),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

({Color bg, Color fg}) _badgeStyle(String status) {
  switch (status) {
    case "upcoming":
      return (bg: const Color(0x1AFFC107), fg: const Color(0xFF8D6E00)); // amber
    case "completed":
      return (bg: const Color(0x1A4CAF50), fg: const Color(0xFF2E7D32)); // green
    case "cancelled":
      return (bg: const Color(0x1AF44336), fg: const Color(0xFFC62828)); // red
    default:
      return (bg: const Color(0x1A9E9E9E), fg: const Color(0xFF616161)); // grey
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
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
