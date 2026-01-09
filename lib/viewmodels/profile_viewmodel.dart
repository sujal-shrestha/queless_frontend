import 'package:flutter/material.dart';
import 'package:queless_app/data/services/api_service.dart';
import '../data/models/profile_model.dart';

class ProfileViewModel extends ChangeNotifier {
  bool isLoading = false;
  String? error;
  ProfileModel? profile;

  Future<void> loadProfile() async {
    isLoading = true;
    error = null;
    notifyListeners();

    final res = await ApiService.fetchProfile();

    isLoading = false;

    if (res['success'] == true) {
      profile = ProfileModel.fromJson(res['data'] as Map<String, dynamic>);
      notifyListeners();
      return;
    }

    error = (res['message'] ?? 'Failed to load profile').toString();
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final res = await ApiService.updateProfile(
      name: name,
      email: email,
      phone: phone,
    );

    isLoading = false;

    if (res['success'] == true) {
      final updated = ProfileModel.fromJson(res['data'] as Map<String, dynamic>);
      profile = updated;
      notifyListeners();
      return true;
    }

    error = (res['message'] ?? 'Update failed').toString();
    notifyListeners();
    return false;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();

    final res = await ApiService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    isLoading = false;

    if (res['success'] == true) {
      notifyListeners();
      return true;
    }

    error = (res['message'] ?? 'Password change failed').toString();
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await ApiService.logout();
  }
}
