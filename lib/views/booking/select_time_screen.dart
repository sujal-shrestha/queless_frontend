import 'package:flutter/material.dart';
import 'booking_flow_args.dart';

class SelectTimeScreen extends StatefulWidget {
  const SelectTimeScreen({super.key});

  @override
  State<SelectTimeScreen> createState() => _SelectTimeScreenState();
}

class _SelectTimeScreenState extends State<SelectTimeScreen> {
  String? selectedTime;

  final List<Map<String, dynamic>> slots = const [
    {'t': '9:00 AM', 'booked': false},
    {'t': '9:30 AM', 'booked': false},
    {'t': '10:00 AM', 'booked': true},
    {'t': '10:30 AM', 'booked': false},
    {'t': '11:00 AM', 'booked': false},
    {'t': '11:30 AM', 'booked': true},
    {'t': '2:00 PM', 'booked': false},
    {'t': '2:30 PM', 'booked': false},
    {'t': '3:00 PM', 'booked': true},
    {'t': '3:30 PM', 'booked': false},
    {'t': '4:00 PM', 'booked': false},
    {'t': '4:30 PM', 'booked': false},
  ];

  void _confirm(BookingDraft draft) {
    if (selectedTime == null) return;

    final args = BookingConfirmedArgs(
      queueNumber: 'A-12',
      venueName: draft.venueName,
      branchName: draft.branchName ?? 'Branch',
      date: draft.date ?? DateTime.now(),
      timeLabel: selectedTime!,
    );

    Navigator.pushReplacementNamed(context, '/booking-confirmed', arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ModalRoute.of(context)!.settings.arguments as BookingDraft;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: const Color(0xFF7CD39A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Time Slot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: slots.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, i) {
                  final s = slots[i];
                  final t = s['t'] as String;
                  final booked = s['booked'] as bool;
                  final isSelected = selectedTime == t;

                  return GestureDetector(
                    onTap: booked
                        ? null
                        : () => setState(() {
                              selectedTime = t;
                            }),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: booked
                            ? const Color(0xFFF3F4F6)
                            : isSelected
                                ? const Color(0xFF16C25A).withOpacity(0.12)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF16C25A) : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: booked ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            booked ? 'Booked' : '',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7CD39A),
                      disabledBackgroundColor: const Color(0xFF7CD39A).withOpacity(0.35),
                    ),
                    onPressed: selectedTime == null ? null : () => _confirm(draft),
                    child: const Text('Confirm Booking'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
