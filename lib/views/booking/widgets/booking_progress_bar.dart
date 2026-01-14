import 'package:flutter/material.dart';

class BookingProgressBar extends StatelessWidget {
  /// 1-based step: 1..total
  final int step;
  final int total;

  const BookingProgressBar({
    super.key,
    required this.step,
    this.total = 4,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final safeStep = step.clamp(1, total);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: List.generate(total, (i) {
          final active = i < safeStep; // ✅ correct for 1-based step
          return Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 8),
              decoration: BoxDecoration(
                color: active ? primary : const Color(0xFFE6EAF0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          );
        }),
      ),
    );
  }
}
