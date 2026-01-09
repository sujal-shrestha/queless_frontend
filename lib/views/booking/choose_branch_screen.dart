import 'package:flutter/material.dart';
import 'booking_flow_args.dart';

class ChooseBranchScreen extends StatefulWidget {
  const ChooseBranchScreen({super.key});

  @override
  State<ChooseBranchScreen> createState() => _ChooseBranchScreenState();
}

class _ChooseBranchScreenState extends State<ChooseBranchScreen> {
  String? selectedBranchId;
  String? selectedBranchName;

  final List<Map<String, dynamic>> branches = const [
    {'id': 'b1', 'name': 'Hattigauda', 'rating': 4.9, 'distance': '2.5 km', 'available': true},
    {'id': 'b2', 'name': 'New Road', 'rating': 4.8, 'distance': '4.2 km', 'available': true},
    {'id': 'b3', 'name': 'Hattisar', 'rating': 4.3, 'distance': '12.9 km', 'available': false},
    {'id': 'b4', 'name': 'Budanilkantha', 'rating': 4.5, 'distance': '8.0 km', 'available': true},
  ];

  void _continue(BookingDraft draft) {
    if (selectedBranchId == null || selectedBranchName == null) return;
    final next = draft.copyWith(branchId: selectedBranchId, branchName: selectedBranchName);
    Navigator.pushNamed(context, '/select-date', arguments: next);
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
      body: Column(
        children: [
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose Your Branch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: branches.length,
              itemBuilder: (context, i) {
                final b = branches[i];
                final isSelected = selectedBranchId == b['id'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedBranchId = b['id'] as String;
                      selectedBranchName = b['name'] as String;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF16C25A) : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b['name'] as String,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text('${b['rating']}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 12),
                            const Icon(Icons.place_rounded, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${b['distance']}', style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            _AvailabilityChip(available: b['available'] as bool),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
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
                    onPressed: selectedBranchId == null ? null : () => _continue(draft),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  final bool available;

  const _AvailabilityChip({required this.available});

  @override
  Widget build(BuildContext context) {
    final bg = available ? Colors.black : const Color(0xFFE5E7EB);
    final fg = available ? Colors.white : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(available ? 'Available' : 'Unavailable', style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
