import 'package:flutter/material.dart';
import '../../data/services/booking_service.dart';

class ChooseBranchScreen extends StatefulWidget {
  const ChooseBranchScreen({super.key});

  @override
  State<ChooseBranchScreen> createState() => _ChooseBranchScreenState();
}

class _ChooseBranchScreenState extends State<ChooseBranchScreen> {
  final BookingService _service = BookingService();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _loading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked == null) return;
    setState(() => _selectedTime = picked);
  }

  DateTime _combinedDateTime() {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  Future<void> _confirm(String venueId) async {
    setState(() => _loading = true);

    final scheduledAt = _combinedDateTime();

    final res = await _service.createBooking(
      venueId: venueId,
      title: "Appointment",
      scheduledAt: scheduledAt,
    );

    setState(() => _loading = false);

    final status = res['statusCode'] as int;
    final data = res['data'];

    if (status < 200 || status >= 300) {
      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Booking failed';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Booking confirmed")),
    );

    Navigator.of(context).popUntil((r) => r.settings.name == '/home' || r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final venueId = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Branch"),
        backgroundColor: const Color(0xFF7CD39A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Selected Venue ID: $venueId", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),

            const Text("Select appointment date & time", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text("${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, "0")}-${_selectedDate.day.toString().padLeft(2, "0")}"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : () => _confirm(venueId),
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Confirm Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
