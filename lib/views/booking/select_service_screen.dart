import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../data/services/api_service.dart';
import '../../viewmodels/venue_viewmodel.dart';
import 'widgets/booking_progress_bar.dart';

class SelectServiceScreen extends StatefulWidget {
  final bool isTab;
  const SelectServiceScreen({super.key, this.isTab = false});

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  // 0 = venue, 1 = branch, 2 = date, 3 = time, 4 = confirmed
  int _step = 0;

  final _search = TextEditingController();
  Timer? _debounce;

  // selections
  String? _venueId;
  String? _venueName;

  String? _branchId;
  String? _branchName;

  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _selectedTime;

  bool _isConfirming = false;

  // ✅ Dynamic branches per venue
  bool _branchesLoading = false;
  String? _branchesError;
  List<_BranchItem> _branches = [];

  // ✅ Confirmed ticket data
  String? _confirmedQueueNumber;
  String? _confirmedTicketToken;
  String? _confirmedVenueName;
  String? _confirmedBranchName;
  DateTime? _confirmedDate;
  String? _confirmedTimeLabel;

  // ✅ Capture ticket as image (QR + details)
  final GlobalKey _ticketKey = GlobalKey();

  static const Color kGreen = Color(0xFF65BF61);

  // demo time slots (later fetch by branch+date)
  final List<Map<String, dynamic>> _slots = const [
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

  @override
  void initState() {
    super.initState();

    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _focusedDay = _selectedDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<VenueViewModel>();
      if (vm.venues.isEmpty && !vm.isLoading) {
        vm.loadVenues();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<VenueViewModel>().loadVenues(search: v);
    });
  }
Future<void> _pickVenueAndContinue() async {
  if (_venueId == null || _venueName == null) return;

  setState(() => _step = 1); // go to Branch step
  await _loadBranchesForVenue(_venueId!!);

  // if only 1 branch, _loadBranchesForVenue auto-jumps to step 2
}

void _pickBranchAndContinue() {
  if (_branchId == null || _branchName == null) return;
  _nextStep(); // go to Date step
}

void _pickDateAndContinue() {
  // normalize date (remove time)
  setState(() {
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _focusedDay = _selectedDate;

    // optional: reset time when date changes
    _selectedTime = null;
  });

  _nextStep(); // go to Time step
}
  void _nextStep() {
    if (_step < 4) setState(() => _step++);
  }

  void _prevStep() {
    if (_step > 0) setState(() => _step--);
  }

  // =========================
  // ✅ BRANCHES (dynamic per venue)
  // =========================
  Future<void> _loadBranchesForVenue(String venueId) async {
  setState(() {
    _branchesLoading = true;
    _branchesError = null;
    _branches = [];
    _branchId = null;
    _branchName = null;
  });

  try {
    final token = await ApiService.getToken(); // ✅ get saved token
    if (token == null || token.isEmpty) {
      setState(() {
        _branchesError = 'Not authorized, no token';
      });
      return;
    }

    final url = Uri.parse('${ApiService.baseUrl}/api/venues/$venueId/branches');

    final res = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token', // ✅ add token
      },
    ).timeout(const Duration(seconds: 12));

    dynamic parsed;
    try {
      parsed = jsonDecode(res.body);
    } catch (_) {
      parsed = res.body;
    }

    print('[BRANCHES] ${res.statusCode} -> $parsed');

    if (res.statusCode < 200 || res.statusCode >= 300) {
      setState(() {
        _branchesError = (parsed is Map && parsed['message'] != null)
            ? parsed['message'].toString()
            : 'Failed to load branches (${res.statusCode})';
      });
      return;
    }

    List list = [];
    if (parsed is Map && parsed['branches'] is List) list = parsed['branches'];
    if (parsed is Map && parsed['data'] is List) list = parsed['data'];
    if (parsed is List) list = parsed;

    final items = list
        .where((e) => e is Map)
        .map((e) => _BranchItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    setState(() => _branches = items);

    // ✅ If only ONE branch, auto select and skip step
    if (items.length == 1) {
      setState(() {
        _branchId = items.first.id;
        _branchName = items.first.name;
        _step = 2;
      });
    }
  } catch (e) {
    setState(() => _branchesError = 'Network error: $e');
  } finally {
    if (mounted) setState(() => _branchesLoading = false);
  }
}


  // -------------------------
  // TIME PARSING -> scheduledAt
  // -------------------------
  int _parseHour12(String timeLabel) {
    final parts = timeLabel.trim().split(' ');
    if (parts.length != 2) return 0;

    final hm = parts[0].split(':');
    final ampm = parts[1].toUpperCase();

    final h = int.tryParse(hm[0]) ?? 0;
    final isPm = ampm == 'PM';

    int hour24 = h % 12;
    if (isPm) hour24 += 12;
    return hour24;
  }

  int _parseMinute(String timeLabel) {
    final parts = timeLabel.trim().split(' ');
    if (parts.isEmpty) return 0;
    final hm = parts[0].split(':');
    if (hm.length < 2) return 0;
    return int.tryParse(hm[1]) ?? 0;
  }

  DateTime _buildScheduledAt(DateTime date, String timeLabel) {
    final hour = _parseHour12(timeLabel);
    final minute = _parseMinute(timeLabel);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  // =========================
  // ✅ BOOKING CONFIRM (UPDATED: branchId required)
  // =========================
  Future<void> _confirmBooking() async {
    if (_venueId == null || _venueName == null) return;
    if (_branchId == null || _branchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a branch')));
      setState(() => _step = 1);
      return;
    }
    if (_selectedTime == null) return;

    setState(() => _isConfirming = true);

    final scheduledAt = _buildScheduledAt(
      DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      _selectedTime!,
    );

    final title = (_branchName != null && _branchName!.trim().isNotEmpty)
        ? '${_venueName!} - ${_branchName!}'
        : _venueName!;

    final res = await ApiService.createBooking(
      venueId: _venueId!,
      branchId: _branchId!, // ✅ REQUIRED NOW
      title: title,
      scheduledAt: scheduledAt,
    );

    if (!mounted) return;
    setState(() => _isConfirming = false);

    if (res['success'] == true) {
      // ApiService returns: { success:true, data: parsedJson }
      final parsed = res['data'];

      // Your backend createBooking returns:
      // { success:true, message:"Booking created", data:{ booking, queueNumber, ticketToken } }
      final extracted = _extractTicket(parsed);

      final queue = extracted.queueNumber.isNotEmpty ? extracted.queueNumber : '--';
      final token = extracted.ticketToken;

      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created, but ticket token missing. Check backend response.')),
        );
      }

      setState(() {
        _confirmedQueueNumber = queue;
        _confirmedTicketToken = token;
        _confirmedVenueName = _venueName!;
        _confirmedBranchName = (_branchName?.trim().isNotEmpty ?? false) ? _branchName! : 'Branch';
        _confirmedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
        _confirmedTimeLabel = _selectedTime!;
        _step = 4;
      });

      return;
    }

    final msg = (res['message'] ?? 'Booking failed').toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Robust response parsing (prevents “token missing” when response is nested)
  _TicketExtract _extractTicket(dynamic parsed) {
    String queue = '';
    String token = '';

    if (parsed is Map) {
      // Expected: parsed['data'] is Map
      final data = parsed['data'];
      if (data is Map) {
        queue = (data['queueNumber'] ?? '').toString();
        token = (data['ticketToken'] ?? '').toString();

        final booking = data['booking'];
        if (queue.isEmpty && booking is Map) queue = (booking['queueNumber'] ?? '').toString();
      }

      // Fall back if backend returns different nesting
      token = token.isNotEmpty ? token : (parsed['ticketToken'] ?? '').toString();
      queue = queue.isNotEmpty ? queue : (parsed['queueNumber'] ?? '').toString();

      // Some backends return { data: { data: {...}} }
      if ((queue.isEmpty || token.isEmpty) && data is Map && data['data'] is Map) {
        final inner = data['data'] as Map;
        queue = queue.isNotEmpty ? queue : (inner['queueNumber'] ?? '').toString();
        token = token.isNotEmpty ? token : (inner['ticketToken'] ?? '').toString();
        final booking = inner['booking'];
        if (queue.isEmpty && booking is Map) queue = (booking['queueNumber'] ?? '').toString();
      }
    }

    return _TicketExtract(queueNumber: queue, ticketToken: token);
  }

  void _resetFlow() {
    setState(() {
      _step = 0;
      _venueId = null;
      _venueName = null;
      _branchId = null;
      _branchName = null;

      _branchesLoading = false;
      _branchesError = null;
      _branches = [];

      _selectedDate = DateTime.now();
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      _focusedDay = _selectedDate;
      _selectedTime = null;

      _confirmedQueueNumber = null;
      _confirmedTicketToken = null;
      _confirmedVenueName = null;
      _confirmedBranchName = null;
      _confirmedDate = null;
      _confirmedTimeLabel = null;

      _isConfirming = false;
      _search.clear();
    });

    context.read<VenueViewModel>().loadVenues();
  }

  String get _title {
    switch (_step) {
      case 0:
        return 'Select Service';
      case 1:
        return 'Choose Branch';
      case 2:
        return 'Select Date';
      case 3:
        return 'Select Time';
      default:
        return 'Booking Confirmed';
    }
  }

  // =========================
  // ✅ TICKET IMAGE CAPTURE + SAVE + SHARE
  // =========================
  Future<Uint8List?> _captureTicketPng() async {
    try {
      final ctx = _ticketKey.currentContext;
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

  Future<void> _saveTicketToGallery() async {
    final bytes = await _captureTicketPng();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to capture ticket image')));
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/queueless_ticket_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);

      // ✅ Saves local file path to Gallery
      final bool? success = await GallerySaver.saveImage(file.path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success == true ? 'Ticket saved to Gallery ✅' : 'Failed to save ticket')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _shareTicketImage() async {
    final bytes = await _captureTicketPng();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to capture ticket image')));
      return;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/queueless_ticket.png');
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'My QueueLess Ticket (show this QR at the counter)',
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VenueViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: kGreen,
        elevation: 0,
        automaticallyImplyLeading: !widget.isTab,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            BookingProgressBar(step: _step <= 3 ? _step + 1 : 4, total: 4),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _buildStep(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(VenueViewModel vm) {
    switch (_step) {
      case 0:
        return _stepVenue(vm);
      case 1:
        return _stepBranch();
      case 2:
        return _stepDate();
      case 3:
        return _stepTime();
      default:
        return _stepConfirmed();
    }
  }

  // =========================
  // STEP 0: VENUE
  // =========================
  Widget _stepVenue(VenueViewModel vm) {
    return Column(
      key: const ValueKey('step-venue'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: 'Search venue...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kGreen, width: 2),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Builder(
            builder: (_) {
              if (vm.isLoading) return const Center(child: CircularProgressIndicator());

              if (vm.error != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(vm.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              if (vm.venues.isEmpty) return const Center(child: Text('No venues found'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: vm.venues.length,
                itemBuilder: (context, i) {
                  final v = vm.venues[i];
                  final isSelected = _venueId == v.id;

                  final hasLogo = (v.logo != null && v.logo!.trim().isNotEmpty);
                  final logoUrl = hasLogo ? '${ApiService.baseUrl}/logos/${v.logo}' : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _venueId = v.id;
                            _venueName = v.name;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? kGreen : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFF2F6F2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: (logoUrl != null)
                                      ? Image.network(
                                          logoUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => _FallbackLogoText(name: v.name),
                                        )
                                      : _FallbackLogoText(name: v.name),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  v.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (isSelected) const Icon(Icons.check_circle, color: kGreen),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                disabledBackgroundColor: kGreen.withOpacity(0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _venueId == null ? null : _pickVenueAndContinue,
              child: const Text('Continue'),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // STEP 1: BRANCH
  // =========================
  Widget _stepBranch() {
    return Column(
      key: const ValueKey('step-branch'),
      children: [
        Expanded(
          child: Builder(
            builder: (_) {
              if (_branchesLoading) return const Center(child: CircularProgressIndicator());

              if (_branchesError != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_branchesError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              if (_branches.isEmpty) {
                return const Center(child: Text('No branches found for this venue'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _branches.length,
                itemBuilder: (context, i) {
                  final b = _branches[i];
                  final isSelected = _branchId == b.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _branchId = b.id;
                        _branchName = b.name;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? kGreen : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          if (b.address.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded, size: 16, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    b.address,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    disabledBackgroundColor: kGreen.withOpacity(0.35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _branchId == null ? null : _pickBranchAndContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // STEP 2: DATE
  // =========================
  Widget _stepDate() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(now.year + 2, 12, 31);

    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    DateTime focused = _focusedDay;
    if (focused.isBefore(firstDay)) focused = firstDay;
    if (focused.isAfter(lastDay)) focused = lastDay;

    return Padding(
      key: const ValueKey('step-date'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TableCalendar(
              firstDay: firstDay,
              lastDay: lastDay,
              focusedDay: focused,
              currentDay: DateTime(now.year, now.month, now.day),
              selectedDayPredicate: (day) => isSameDay(day, selected),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (fd) => setState(() => _focusedDay = fd),
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFF6B7280)),
                rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
                titleTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 11),
                weekendStyle: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 11),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                isTodayHighlighted: false,
                selectedDecoration: BoxDecoration(
                  color: kGreen.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: kGreen, width: 2),
                ),
                selectedTextStyle: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800),
                defaultTextStyle: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w500),
                weekendTextStyle: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _prevStep, child: const Text('Back'))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _pickDateAndContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // STEP 3: TIME + CONFIRM
  // =========================
  Widget _stepTime() {
    return Padding(
      key: const ValueKey('step-time'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GridView.builder(
              itemCount: _slots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, i) {
                final s = _slots[i];
                final t = s['t'] as String;
                final booked = s['booked'] as bool;
                final isSelected = _selectedTime == t;

                return GestureDetector(
                  onTap: booked ? null : () => setState(() => _selectedTime = t),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: booked
                          ? const Color(0xFFF3F4F6)
                          : isSelected
                              ? kGreen.withOpacity(0.12)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? kGreen : Colors.grey.shade300,
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
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _prevStep, child: const Text('Back'))),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    disabledBackgroundColor: kGreen.withOpacity(0.35),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (_selectedTime == null || _isConfirming) ? null : _confirmBooking,
                  child: _isConfirming
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Confirm Booking'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // STEP 4: CONFIRMED VIEW
  // =========================
  Widget _stepConfirmed() {
    final token = _confirmedTicketToken ?? '';
    final queue = _confirmedQueueNumber ?? '--';
    final venue = _confirmedVenueName ?? 'Venue';
    final branch = _confirmedBranchName ?? 'Branch';
    final date = _confirmedDate ?? DateTime.now();
    final timeLabel = _confirmedTimeLabel ?? '';

    final bottomPad = 24 + MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      key: const ValueKey('step-confirmed'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
      child: Column(
        children: [
          RepaintBoundary(
            key: _ticketKey,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kGreen.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: kGreen, size: 54),
                  const SizedBox(height: 10),
                  const Text('Booking Confirmed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: token.isEmpty
                        ? const Text('QR unavailable (ticketToken missing)', style: TextStyle(color: Colors.red))
                        : QrImageView(
                            data: token,
                            version: QrVersions.auto,
                            size: 200,
                          ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Show this QR at the counter', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  _kv('Queue Number', queue),
                  _kv('Venue', venue),
                  _kv('Branch', branch),
                  _kv(
                    'Date',
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  ),
                  if (timeLabel.trim().isNotEmpty) _kv('Time', timeLabel),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareTicketImage,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                  onPressed: _saveTicketToGallery,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Save Ticket', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _resetFlow,
              child: const Text('Book Another'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12))),
          Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TicketExtract {
  final String queueNumber;
  final String ticketToken;

  const _TicketExtract({
    required this.queueNumber,
    required this.ticketToken,
  });
}

class _BranchItem {
  final String id;
  final String name;
  final String address;

  _BranchItem({
    required this.id,
    required this.name,
    required this.address,
  });

  factory _BranchItem.fromJson(Map<String, dynamic> json) {
    return _BranchItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
    );
  }
}

class _FallbackLogoText extends StatelessWidget {
  final String name;
  const _FallbackLogoText({required this.name});

  static const Color kGreen = Color(0xFF65BF61);

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Center(
      child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800, color: kGreen)),
    );
  }
}
