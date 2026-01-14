import 'package:flutter/foundation.dart';
import '../data/services/api_service.dart';

class ProfileViewModel extends ChangeNotifier {
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  // Profile fields
  String name = '';
  String username = '';
  String role = '';
  String email = '';
  String phone = '';
  String address = '';
  String memberSince = '—';

  // Stats (from bookings)
  int visits = 0;
  int upcoming = 0;
  double avgRating = 0.0;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // 1) profile
      final profileRes = await ApiService.fetchProfile();
      if (profileRes['success'] != true) {
        _error = profileRes['message']?.toString() ?? 'Failed to load profile';
        _loading = false;
        notifyListeners();
        return;
      }

      final data = profileRes['data'];
      if (data is Map) {
        name = (data['name'] ?? '').toString();
        username = (data['username'] ?? '').toString();
        role = (data['role'] ?? '').toString();
        email = (data['email'] ?? '').toString();
        phone = (data['phone'] ?? '').toString();
        address = (data['address'] ?? '').toString();

        final createdAtRaw = data['createdAt'];
        final dt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw.toString()) : null;
        if (dt != null) {
          memberSince = "${_monthName(dt.month)} ${dt.year}";
        } else {
          memberSince = "—";
        }
      }

      // 2) stats from bookings
      final bookingsRes = await ApiService.fetchMyBookings();
      if (bookingsRes['success'] == true) {
        final list = bookingsRes['data'];
        if (list is List) {
          int v = 0;
          int u = 0;
          double sum = 0;
          int count = 0;

          for (final b in list) {
            if (b is Map) {
              final status = (b['status'] ?? '').toString().toLowerCase().trim();
              if (status == 'completed') v++;
              if (status == 'upcoming') u++;

              // optional rating keys (won’t break if not in backend)
              final r = b['rating'] ?? b['reviewRating'] ?? b['stars'];
              final rating = (r is num) ? r.toDouble() : double.tryParse(r?.toString() ?? '');
              if (rating != null && rating > 0) {
                sum += rating;
                count++;
              }
            }
          }

          visits = v;
          upcoming = u;
          avgRating = count == 0 ? 0.0 : (sum / count);
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> updateMyProfile({
    required String name,
    required String email,
    required String phone,
    required String address,
  }) async {
    final res = await ApiService.updateProfile(
      name: name,
      email: email,
      phone: phone,
      address: address,
    );

    if (res['success'] == true) {
      await load();
      return null;
    }
    return res['message']?.toString() ?? 'Update failed';
  }

  Future<String?> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await ApiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (res['success'] == true) return null;
    return res['message']?.toString() ?? 'Password change failed';
  }

  Future<String?> deleteMyAccount() async {
    final res = await ApiService.deleteAccount();
    if (res['success'] == true) return null;
    return res['message']?.toString() ?? 'Delete failed';
  }

  Future<void> logout() async {
    await ApiService.logout();
  }

  String _monthName(int m) {
    const months = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return (m >= 1 && m <= 12) ? months[m - 1] : "—";
  }
}
