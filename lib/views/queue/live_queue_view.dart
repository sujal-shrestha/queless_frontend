import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:queless_app/data/services/api_service.dart';

class LiveQueueView extends StatefulWidget {
  /// ✅ Pass this from parent (Dashboard/BottomNav) to switch to Booking tab/page.
  /// Example:
  /// LiveQueueView(onGoToBooking: () => setState(() => _currentIndex = 1))
  final VoidCallback? onGoToBooking;

  const LiveQueueView({super.key, this.onGoToBooking});

  @override
  State<LiveQueueView> createState() => _LiveQueueViewState();
}

class _LiveQueueViewState extends State<LiveQueueView> {
  static const Color kGreen = Color(0xFF65BF61);

  Timer? _pollTimer;

  bool _loading = true;
  String? _error;

  // ✅ My booking/ticket
  String? _bookingId;
  String? _venueId;
  String? _branchId;

  String _venueName = "";
  String _branchName = "";

  String _myQueueNumber = "";
  int _myQueueIndex = 0; // 1..50
  String _ticketToken = "";

  // ✅ Live queue
  int _currentServingIndex = 0; // 0 means not started
  String _currentServingNumber = "--";
  int _totalIssued = 0;

  // ✅ Live queue endpoint detection (branch-based vs venue-based)
  String? _liveQueueResolvedUrl;

  // ✅ Minimal notifications toggle (in-app alerts)
  bool _notifyEnabled = true;
  bool _notifiedThreeAway = false;
  bool _notifiedYourTurn = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    await _loadNotifyPreference();
    await _loadMyTodayBooking();
    _startPolling();
  }

  Future<void> _loadNotifyPreference() async {
    final sp = await SharedPreferences.getInstance();
    setState(() => _notifyEnabled = sp.getBool("queue_notify_enabled") ?? true);
  }

  Future<void> _setNotifyPreference(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool("queue_notify_enabled", v);
    setState(() => _notifyEnabled = v);
  }

  // =========================
  // AUTH TOKEN
  // =========================
  Future<String?> _getAuthToken() async {
    final sp = await SharedPreferences.getInstance();

    final t1 = sp.getString("token");
    if (t1 != null && t1.isNotEmpty) return t1;

    final t2 = sp.getString("accessToken");
    if (t2 != null && t2.isNotEmpty) return t2;

    final t3 = sp.getString("jwt");
    if (t3 != null && t3.isNotEmpty) return t3;

    return null;
  }

  Map<String, String> _headers(String token) => {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

  dynamic _safeJsonDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  // =========================
  // 1) GET MY TODAY BOOKING
  // =========================
  Future<void> _loadMyTodayBooking() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getAuthToken();
      if (token == null) {
        setState(() {
          _loading = false;
          _error = "You are not logged in. Please login first.";
        });
        return;
      }

      final url = Uri.parse("${ApiService.baseUrl}/api/bookings/me/today");
      final res = await http.get(url, headers: _headers(token)).timeout(
            const Duration(seconds: 12),
          );

      final parsed = _safeJsonDecode(res.body);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = (parsed is Map && parsed["message"] != null)
            ? parsed["message"].toString()
            : "Server error (${res.statusCode})";
        setState(() {
          _loading = false;
          _error = msg;
        });
        return;
      }

      // Accept many shapes:
      // 1) { success:true, data:{ booking:{...}, queueNumber, queueIndex, ticketToken } }
      // 2) { data:{...} } OR { booking:{...} }
      final root = (parsed is Map) ? parsed : {};
      final data = (root is Map && root["data"] != null) ? root["data"] : root;

      if (data == null || data is! Map) {
        setState(() {
          _loading = false;
          _bookingId = null;
          _venueId = null;
          _branchId = null;
        });
        return;
      }

      final booking = (data["booking"] is Map)
          ? (data["booking"] as Map)
          : (data["data"] is Map && (data["data"] as Map)["booking"] is Map)
              ? ((data["data"] as Map)["booking"] as Map)
              : (data["booking"] is Map)
                  ? (data["booking"] as Map)
                  : null;

      // ids
      final bookingId = _pickString(booking, ["_id", "id"]);
      final venueId = _pickIdToString(booking?["venue"]);
      final branchId = _pickIdToString(booking?["branch"]);

      // queue number/index
      final qn = _firstNonEmptyString([
        _pickString(data, ["queueNumber", "queue_number"]),
        _pickString(booking, ["queueNumber", "queue_number"]),
      ]);

      final qi = _firstNonZeroInt([
        _pickInt(data, ["queueIndex", "queue_index"]),
        _pickInt(booking, ["queueIndex", "queue_index"]),
        _queueIndexFromNumber(qn),
      ]);

      // ticket token
      final tokenStr = _firstNonEmptyString([
        _pickString(data, ["ticketToken", "ticket_token", "token", "qrToken", "qrData"]),
        _pickString(booking, ["ticketToken", "ticket_token", "token", "qrToken", "qrData"]),
      ]);

      // title -> venue + branch name (fallback)
      final title = _pickString(booking, ["title"]);
      final split = _splitVenueBranch(title);

      setState(() {
        _bookingId = bookingId.isEmpty ? null : bookingId;
        _venueId = venueId.isEmpty ? null : venueId;
        _branchId = branchId.isEmpty ? null : branchId;

        _myQueueNumber = qn;
        _myQueueIndex = qi;
        _ticketToken = tokenStr;

        _venueName = split.item1;
        _branchName = split.item2;

        _loading = false;

        // reset notification flags when ticket changes
        _notifiedThreeAway = false;
        _notifiedYourTurn = false;

        // force re-detect live endpoint when booking changes
        _liveQueueResolvedUrl = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = "Network error: $e";
      });
    }
  }

  String _pickIdToString(dynamic v) {
    if (v == null) return "";
    // could be "id", or populated object { _id: ... }
    if (v is String) return v;
    if (v is Map) {
      final id = v["_id"] ?? v["id"];
      return id == null ? "" : id.toString();
    }
    return v.toString();
  }

  String _pickString(dynamic src, List<String> keys) {
    if (src is! Map) return "";
    for (final k in keys) {
      final v = src[k];
      if (v != null) {
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
    }
    return "";
  }

  int _pickInt(dynamic src, List<String> keys) {
    if (src is! Map) return 0;
    for (final k in keys) {
      final v = src[k];
      if (v != null) {
        final n = int.tryParse(v.toString());
        if (n != null) return n;
      }
    }
    return 0;
  }

  String _firstNonEmptyString(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return "";
  }

  int _firstNonZeroInt(List<int> values) {
    for (final v in values) {
      if (v > 0) return v;
    }
    return 0;
  }

  // "Hams Hospital - Budhanilkantha" => venue + branch
  _Pair _splitVenueBranch(String title) {
    final t = title.trim();
    if (t.isEmpty) return _Pair("", "");
    if (t.contains(" - ")) {
      final parts = t.split(" - ");
      final v = parts.isNotEmpty ? parts.first.trim() : t;
      final b = parts.length > 1 ? parts.sublist(1).join(" - ").trim() : "";
      return _Pair(v, b);
    }
    return _Pair(t, "");
  }

  int _queueIndexFromNumber(String q) {
    final m = RegExp(r"(\d+)").firstMatch(q);
    if (m == null) return 0;
    return int.tryParse(m.group(1)!) ?? 0;
  }

  // =========================
  // 2) LIVE QUEUE POLLING
  // =========================
  void _startPolling() {
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      if ((_branchId == null || _branchId!.isEmpty) &&
          (_venueId == null || _venueId!.isEmpty)) return;

      await _fetchLiveQueue();
      _maybeNotify();
    });

    // also fetch immediately once
    _fetchLiveQueue();
  }

  Future<void> _fetchLiveQueue() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      // ✅ If we already detected a working endpoint, use it
      if (_liveQueueResolvedUrl != null && _liveQueueResolvedUrl!.isNotEmpty) {
        await _hitLiveQueueUrl(_liveQueueResolvedUrl!, token);
        return;
      }

      // ✅ Otherwise, try a list of possible endpoints (branch-based first)
      final candidates = <String>[];

      if (_branchId != null && _branchId!.isNotEmpty) {
        candidates.addAll([
          "${ApiService.baseUrl}/api/queue/live/${_branchId!}",
          "${ApiService.baseUrl}/api/queue/live/branch/${_branchId!}",
          "${ApiService.baseUrl}/api/branches/${_branchId!}/queue/live",
          "${ApiService.baseUrl}/api/org/queue/live/${_branchId!}", // some projects used this
        ]);
      }

      if (_venueId != null && _venueId!.isNotEmpty) {
        candidates.addAll([
          "${ApiService.baseUrl}/api/org/queue/live/${_venueId!}", // your old one
          "${ApiService.baseUrl}/api/queue/live/${_venueId!}",
        ]);
      }

      for (final u in candidates) {
        final ok = await _hitLiveQueueUrl(u, token);
        if (ok) {
          if (mounted) setState(() => _liveQueueResolvedUrl = u);
          break;
        }
      }
    } catch (_) {
      // keep silent for polling
    }
  }

  Future<bool> _hitLiveQueueUrl(String url, String token) async {
    final uri = Uri.parse(url);

    final res = await http.get(uri, headers: _headers(token)).timeout(
          const Duration(seconds: 10),
        );

    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    final parsed = _safeJsonDecode(res.body);
    final data = (parsed is Map) ? (parsed["data"] ?? parsed) : parsed;

    // read flexible keys
    final currentIndex = _pickInt(data, [
      "currentServingIndex",
      "currentIndex",
      "nowServingIndex",
      "servingIndex",
      "current",
    ]);

    final currentNumber = _pickString(data, [
      "currentServingNumber",
      "currentServing",
      "nowServingNumber",
      "queueNumber",
      "nowServing",
    ]);

    final totalIssued = _pickInt(data, [
      "totalIssued",
      "totalQueue",
      "issued",
      "count",
      "total",
    ]);

    if (!mounted) return true;

    setState(() {
      _currentServingIndex = currentIndex > 0 ? currentIndex : _currentServingIndex;
      _currentServingNumber = currentNumber.isNotEmpty ? currentNumber : _currentServingNumber;
      _totalIssued = totalIssued > 0 ? totalIssued : _totalIssued;
    });

    return true;
  }

  // =========================
  // 3) MINIMAL “NOTIFICATIONS”
  // =========================
  void _maybeNotify() {
    if (!_notifyEnabled) return;
    if (_myQueueIndex <= 0) return;

    final ahead = peopleAhead;

    if (!_notifiedThreeAway && ahead == 3) {
      _notifiedThreeAway = true;
      _snack("Almost your turn — you’re 3 away ✅");
    }

    if (!_notifiedYourTurn && ahead <= 0 && _currentServingIndex >= _myQueueIndex) {
      _notifiedYourTurn = true;
      _snack("It’s your turn now! Please go to the counter ✅");
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =========================
  // UI COMPUTED
  // =========================
  int get peopleAhead {
    if (_myQueueIndex <= 0) return 0;
    if (_currentServingIndex <= 0) return _myQueueIndex - 1;
    return (_myQueueIndex - _currentServingIndex).clamp(0, 999);
  }

  double get progress {
    if (_myQueueIndex <= 0) return 0;
    final served = _currentServingIndex.clamp(0, _myQueueIndex);
    return served / _myQueueIndex;
  }

  List<int> get _miniList {
    final start = (_currentServingIndex <= 0) ? 1 : _currentServingIndex;
    final end = start + 7;

    final list = <int>[];
    for (int i = start; i <= end; i++) {
      if (i >= 1 && i <= 50) list.add(i);
    }

    if (_myQueueIndex > 0 && !list.contains(_myQueueIndex)) {
      list.add(_myQueueIndex);
      list.sort();
    }

    return list;
  }

  String _formatQueue(int idx) => "A-${idx.toString().padLeft(2, "0")}";

  // =========================
  // NAV: Go to Booking
  // =========================
  void _goToBooking() {
    if (widget.onGoToBooking != null) {
      widget.onGoToBooking!();
      return;
    }

    // fallback: try pop (if this view was pushed)
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
      return;
    }

    // last fallback: show hint
    _snack("Connect onGoToBooking to open booking screen.");
  }

  // =========================
  // BUILD
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text("Live Queue Status"),
        backgroundColor: kGreen,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : () async {
                    await _loadMyTodayBooking();
                    _startPolling();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : (_bookingId == null || (_branchId == null && _venueId == null))
                    ? _noBookingState()
                    : _queueBody(),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              _error ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _boot,
                child: const Text("Try Again"),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _goToBooking,
                child: const Text("Go to Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noBookingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.confirmation_num_outlined, size: 44, color: Colors.black54),
            const SizedBox(height: 10),
            const Text(
              "No ticket for today",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              "Book an appointment first, then your live queue will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _goToBooking,
                child: const Text("Go to Booking"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueBody() {
    final ahead = peopleAhead;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadMyTodayBooking();
        await _fetchLiveQueue();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: Column(
          children: [
            _topNowServingCard(),
            const SizedBox(height: 14),
            _myTicketCard(ahead),
            const SizedBox(height: 14),
            _miniQueueCard(),
            const SizedBox(height: 14),
            _notifyCard(),
          ],
        ),
      ),
    );
  }

  Widget _topNowServingCard() {
    final serving = (_currentServingIndex > 0) ? _formatQueue(_currentServingIndex) : _currentServingNumber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _venueName.isEmpty ? "Current Queue" : _venueName,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          if (_branchName.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _branchName,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            "Now Serving",
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            serving,
            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            "Live update • refresh anytime",
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _myTicketCard(int ahead) {
    final statusText = (ahead <= 0) ? "Your turn" : "$ahead ahead";
    final myNumber = _myQueueNumber.isNotEmpty ? _myQueueNumber : _formatQueue(_myQueueIndex);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Your Ticket", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  myNumber,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kGreen),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (ahead <= 0) ? kGreen.withOpacity(0.15) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusText, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 10,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: const AlwaysStoppedAnimation<Color>(kGreen),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                "Progress ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%",
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                "Total issued: ${_totalIssued == 0 ? "—" : _totalIssued}",
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _ticketToken.trim().isEmpty ? null : () => _showQrSheet(token: _ticketToken, queueNo: myNumber),
              icon: const Icon(Icons.qr_code_2),
              label: const Text("View QR"),
            ),
          ),
          if (_ticketToken.trim().isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              "QR not available (ticketToken missing from backend response)",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniQueueCard() {
    final list = _miniList;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Current Queue", style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...list.map((idx) {
            final isServing = idx == _currentServingIndex;
            final isMine = idx == _myQueueIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isServing
                    ? kGreen.withOpacity(0.12)
                    : isMine
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isServing
                      ? kGreen
                      : isMine
                          ? const Color(0xFF93C5FD)
                          : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      idx.toString().padLeft(2, "0"),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Queue ${_formatQueue(idx)}",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (isServing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(999)),
                      child: const Text(
                        "Now Serving",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    )
                  else if (isMine)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFFBFDBFE), borderRadius: BorderRadius.circular(999)),
                      child: const Text(
                        "You",
                        style: TextStyle(color: Color(0xFF0B3B8A), fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _notifyCard() {
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
          const Icon(Icons.notifications_active_outlined, color: kGreen),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Notify me when it’s close", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          Switch(
            value: _notifyEnabled,
            activeColor: kGreen,
            onChanged: (v) => _setNotifyPreference(v),
          ),
        ],
      ),
    );
  }

  // =========================
  // QR SHEET
  // =========================
  void _showQrSheet({required String token, required String queueNo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final safeToken = token.trim();

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Ticket QR • $queueNo",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: QrImageView(
                  data: safeToken,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Show this at the counter",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: safeToken));
                        if (mounted) Navigator.pop(context);
                        _snack("Token copied ✅");
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy Token"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: kGreen),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text("Done", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                safeToken,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pair {
  final String item1;
  final String item2;
  _Pair(this.item1, this.item2);
}
