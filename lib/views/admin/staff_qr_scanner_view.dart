import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:queless_app/data/services/api_service.dart';

class StaffQrScannerView extends StatefulWidget {
  final String branchId;
  final String dateKey;

  const StaffQrScannerView({
    super.key,
    required this.branchId,
    required this.dateKey,
  });

  @override
  State<StaffQrScannerView> createState() => _StaffQrScannerViewState();
}

class _StaffQrScannerViewState extends State<StaffQrScannerView> {
  static const Color kGreen = Color(0xFF65BF61);

  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  bool _consume = true; // verify + check-in by default

  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verifyToken(String ticketToken) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _error = null;
      _result = null;
    });

    try {
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        setState(() => _error = "Not logged in");
        return;
      }

      final url = Uri.parse("${ApiService.baseUrl}/api/queue/verify-ticket");

      final res = await http.post(
        url,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "ticketToken": ticketToken,
          "branchId": widget.branchId,
          "dateKey": widget.dateKey,
          "consume": _consume,
        }),
      );

      final parsed = res.body.trim().isEmpty ? {} : jsonDecode(res.body);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final msg = (parsed is Map && parsed["message"] != null)
            ? parsed["message"].toString()
            : "Verification failed (${res.statusCode})";
        setState(() => _error = msg);
        return;
      }

      setState(() {
        _result = (parsed is Map) ? (parsed["data"] ?? parsed) : {};
      });
    } catch (e) {
      setState(() => _error = "Failed: $e");
    } finally {
      setState(() => _processing = false);
    }
  }

  void _resetScan() {
    setState(() {
      _error = null;
      _result = null;
      _processing = false;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text("Scan Ticket QR"),
        backgroundColor: kGreen,
        actions: [
          IconButton(
            onPressed: _resetScan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) async {
                    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
                    final raw = barcode?.rawValue?.trim();

                    if (raw == null || raw.isEmpty) return;

                    // stop scanning to avoid duplicates
                    _controller.stop();

                    await _verifyToken(raw);
                  },
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Align the QR in the box",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: _consume,
                          onChanged: (v) => setState(() => _consume = v),
                          activeColor: kGreen,
                        ),
                        Text(
                          _consume ? "Check-in" : "Verify",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Result panel
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _processing
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _errorCard(_error!)
                      : _result != null
                          ? _successCard(_result!)
                          : _hintCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Text(
        "Scan a customer ticket QR to verify it.\n\nToggle:\n• Verify = just checks validity\n• Check-in = verifies + consumes ticket",
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54),
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Invalid / Not Allowed", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC62828))),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen),
              onPressed: _resetScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan Again", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _successCard(Map<String, dynamic> data) {
    final qn = (data["queueNumber"] ?? "--").toString();
    final status = (data["status"] ?? "--").toString();
    final usedAt = data["usedAt"]?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("VALID ✅", style: TextStyle(fontWeight: FontWeight.w900, color: kGreen, fontSize: 18)),
          const SizedBox(height: 10),
          Text("Queue: $qn", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text("Status: $status", style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
          if (usedAt != null) ...[
            const SizedBox(height: 6),
            Text("Used At: $usedAt", style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: kGreen),
              onPressed: _resetScan,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan Next", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
