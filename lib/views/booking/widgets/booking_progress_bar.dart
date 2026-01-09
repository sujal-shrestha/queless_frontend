// lib/views/booking/widgets/booking_progress_bar.dart
import 'package:flutter/material.dart';

class BookingProgressBar extends StatelessWidget {
  final int step; // 1..4

  const BookingProgressBar({super.key, required this.step});

  @override
  Widget build(BuildContext context) {
    const total = 4;

    return Row(
      children: List.generate(total, (i) {
        final active = (i + 1) <= step;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        );
      }),
    );
  }
}
