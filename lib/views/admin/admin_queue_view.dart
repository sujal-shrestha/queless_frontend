import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:queless_app/data/services/api_service.dart';

// ✅ NEW: QR scanner screen
import 'staff_qr_scanner_view.dart';

class AdminQueueView extends StatefulWidget {
  final String branchId;
  final String branchName;

  // ✅ NEW: show Venue + Branch like "Nabil Bank, Dhumbarahi"
  final String venueName;

  const AdminQueueView({
    super.key,
    required this.branchId,
    required this.branchName,
    required this.venueName,
  });

  @override
  State<AdminQueueView> createState() => _AdminQueueViewState();
}

class _AdminQueueViewState extends State<AdminQueueView> {
  static const Color kGreen = Color(0xFF65BF61);

  Timer? _timer;
  bool _loading = true;
  String? _error;

  bool _started = false;
  int _currentServingIndex = 0;
  int _totalIssued = 0;

  String _dateKey = ""; // YYYY-MM-DD
  DateTime _selectedDate = DateTime.now();

  List<dynamic> _appointments = [];

  @override
  void initState() {
    super.initState();
    _dateKey = _fmtDateKey(_selectedDate);
    _fetchAll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchLive(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtDateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, "0");
    final m = d.month.toString().padLeft(2, "0");
    final day = d.day.toString().padLeft(2, "0");
    return "$y-$m-$day";
  }

  String _formatQueue(int idx) => "A-${idx.toString().padLeft(2, "0")}";

  Future<String?> _token() => ApiService.getToken();

  Map<String, String> _headers(String token) => {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchLive(), _fetchAppointments()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchLive({bool silent = false}) async {
    if (!silent) setState(() => _error = null);

    final token = await _token();
    if (token == null || token.isEmpty) {
      if (!silent) setState(() => _error = "Not logged in");
      return;
    }

    // ✅ GET /api/queue/live/:branchId?date=YYYY-MM-DD
    final url = Uri.parse("${ApiService.baseUrl}/api/queue/live/${widget.branchId}?date=$_dateKey");

    try {
      final res = await http.get(url, headers: _headers(token));
      final parsed = res.body.trim().isEmpty ? {} : jsonDecode(res.body);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (!silent) {
          final msg = (parsed is Map && parsed["message"] != null)
              ? parsed["message"].toString()
              : "Failed (${res.statusCode})";
          setState(() => _error = msg);
        }
        return;
      }

      final data = (parsed is Map) ? (parsed["data"] ?? parsed) : {};

      if (!mounted) return;
      setState(() {
        _error = null;
        _started = (data["started"] ?? false) == true;
        _currentServingIndex = (data["currentServingIndex"] ?? 0) is int
            ? data["currentServingIndex"]
            : int.tryParse((data["currentServingIndex"] ?? "0").toString()) ?? 0;
        _totalIssued = (data["totalIssued"] ?? 0) is int
            ? data["totalIssued"]
            : int.tryParse((data["totalIssued"] ?? "0").toString()) ?? 0;
      });
    } catch (e) {
      if (!silent && mounted) setState(() => _error = "Failed: $e");
    }
  }

  Future<void> _fetchAppointments() async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      setState(() => _error = "Not logged in");
      return;
    }

    // ✅ GET /api/queue/:branchId/appointments?date=YYYY-MM-DD
    final url = Uri.parse("${ApiService.baseUrl}/api/queue/${widget.branchId}/appointments?date=$_dateKey");

    try {
      final res = await http.get(url, headers: _headers(token));
      final parsed = res.body.trim().isEmpty ? {} : jsonDecode(res.body);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = (parsed is Map && parsed["message"] != null)
            ? parsed["message"].toString()
            : "Failed to load appointments";
        setState(() => _error = msg);
        return;
      }

      final data = (parsed is Map) ? (parsed["data"] ?? []) : [];
      setState(() => _appointments = (data is List) ? data : []);
    } catch (e) {
      setState(() => _error = "Failed: $e");
    }
  }

  Future<void> _startDay() async {
    final token = await _token();
    if (token == null || token.isEmpty) return;

    // POST /api/queue/:branchId/start?date=
    final url = Uri.parse("${ApiService.baseUrl}/api/queue/${widget.branchId}/start?date=$_dateKey");

    final res = await http.post(url, headers: _headers(token));
    final parsed = res.body.trim().isEmpty ? {} : jsonDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (parsed is Map && parsed["message"] != null)
          ? parsed["message"].toString()
          : "Failed to start day";
      _snack(msg);
      return;
    }

    _snack("Day started ✅");
    await _fetchAll();
  }

  Future<void> _nextTicket() async {
    final token = await _token();
    if (token == null || token.isEmpty) return;

    // POST /api/queue/:branchId/next?date=
    final url = Uri.parse("${ApiService.baseUrl}/api/queue/${widget.branchId}/next?date=$_dateKey");

    final res = await http.post(url, headers: _headers(token));
    final parsed = res.body.trim().isEmpty ? {} : jsonDecode(res.body);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (parsed is Map && parsed["message"] != null)
          ? parsed["message"].toString()
          : "Failed to advance";
      _snack(msg);
      return;
    }

    await _fetchLive();
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StaffQrScannerView(
          branchId: widget.branchId,
          dateKey: _dateKey,
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _dateKey = _fmtDateKey(picked);
    });

    await _fetchAll();
  }

  // ✅ NEW: Logout
  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout?"),
        content: const Text("You will be signed out of the staff dashboard."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ApiService.logout();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/auth", (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final nowServingText = _currentServingIndex <= 0 ? "--" : _formatQueue(_currentServingIndex);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text("Staff • Queue"),
        backgroundColor: kGreen,
        actions: [
          IconButton(onPressed: _fetchAll, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(fontWeight: FontWeight.w800)))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _headerCard(),
                        const SizedBox(height: 12),
                        _nowServingCard(nowServingText),
                        const SizedBox(height: 12),
                        _actionsRowWithCenterScanner(),
                        const SizedBox(height: 12),
                        Expanded(child: _appointmentsList()),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _headerCard() {
    final venue = widget.venueName.trim();
    final branch = widget.branchName.trim();

    final title = venue.isNotEmpty ? "$venue, $branch" : branch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.store, color: kGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text("Date: $_dateKey", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: const Text("Change"),
          ),
        ],
      ),
    );
  }

  Widget _nowServingCard(String nowServingText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            _started ? "Day Started ✅" : "Day Not Started",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _started ? kGreen : Colors.redAccent,
            ),
          ),
          const SizedBox(height: 10),
          const Text("Now Serving", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(
            nowServingText,
            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: kGreen),
          ),
          const SizedBox(height: 6),
          Text(
            "Total issued: $_totalIssued",
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _actionsRowWithCenterScanner() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _started ? Colors.grey.shade400 : kGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _started ? null : _startDay,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text("Start Day", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ),
        const SizedBox(width: 12),

        SizedBox(
          width: 72,
          height: 72,
          child: InkWell(
            onTap: _started ? _openScanner : null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _started
                      ? [kGreen, const Color(0xFF2AAE63)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 34),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: 72,
          height: 72,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              backgroundColor: kGreen,
              disabledBackgroundColor: Colors.grey.shade400,
              elevation: 4,
            ),
            onPressed: _started ? _nextTicket : null,
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _appointmentsList() {
    if (_appointments.isEmpty) {
      return const Center(child: Text("No appointments for this date"));
    }

    return ListView.builder(
      itemCount: _appointments.length,
      itemBuilder: (_, i) {
        final b = _appointments[i] as Map<String, dynamic>;
        final idx = b["queueIndex"] ?? 0;
        final qn = b["queueNumber"] ?? "";
        final title = (b["title"] ?? "Customer").toString();
        final status = (b["status"] ?? "upcoming").toString();

        final isServing = idx == _currentServingIndex;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isServing ? kGreen.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isServing ? kGreen : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  (qn.toString().isNotEmpty ? qn.toString() : _formatQueue(idx)).replaceAll("A-", ""),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text("Status: $status", style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              if (isServing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(999)),
                  child: const Text("NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        );
      },
    );
  }
}
