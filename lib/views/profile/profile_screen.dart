import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const primary = Color(0xFF65BF61);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ProfileViewModel>().load());
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<bool> _doubleConfirm({
    required String title1,
    required String msg1,
    required String title2,
    required String msg2,
    required String confirmText,
    Color confirmColor = Colors.red,
  }) async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title1),
        content: Text(msg1),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    if (step1 != true) return false;

    final step2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title2),
        content: Text(msg2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return step2 == true;
  }

  Future<void> _openEditProfile(ProfileViewModel vm) async {
    final nameC = TextEditingController(text: vm.name);
    final emailC = TextEditingController(text: vm.email);
    final phoneC = TextEditingController(text: vm.phone);
    final addressC = TextEditingController(text: vm.address);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Profile"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "Full Name")),
              TextField(controller: emailC, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Phone")),
              TextField(controller: addressC, decoration: const InputDecoration(labelText: "Address")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Save")),
        ],
      ),
    );

    if (ok != true) return;

    final err = await vm.updateMyProfile(
      name: nameC.text.trim(),
      email: emailC.text.trim(),
      phone: phoneC.text.trim(),
      address: addressC.text.trim(),
    );

    if (!mounted) return;

    if (err == null) {
      _snack("Profile updated");
    } else {
      _snack(err);
    }
  }

  Future<void> _openChangePassword(ProfileViewModel vm) async {
    final currentC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Change Password"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: currentC,
                decoration: const InputDecoration(labelText: "Current password"),
                obscureText: true,
              ),
              TextField(
                controller: newC,
                decoration: const InputDecoration(labelText: "New password"),
                obscureText: true,
              ),
              TextField(
                controller: confirmC,
                decoration: const InputDecoration(labelText: "Confirm new password"),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Update")),
        ],
      ),
    );

    if (ok != true) return;

    if (newC.text.trim() != confirmC.text.trim()) {
      _snack("New passwords do not match");
      return;
    }

    final err = await vm.changeMyPassword(
      currentPassword: currentC.text,
      newPassword: newC.text,
    );

    if (!mounted) return;

    if (err == null) {
      _snack("Password updated");
    } else {
      _snack(err);
    }
  }

  void _goToLogin() {
    // ✅ Replace '/login' with your real login route name if different
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: vm.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // HEADER (green + rounded)
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    decoration: const BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Back (only if can pop)
                        InkWell(
                          onTap: () {
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.chevron_left, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Profile",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: vm.loading ? null : () => context.read<ProfileViewModel>().load(),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        children: [
                          if (vm.error != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: Text(vm.error!, style: const TextStyle(color: Colors.red)),
                            ),

                          // PROFILE CARD
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // top info row
                                Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF3F1),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: const Icon(Icons.person, color: primary, size: 30),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vm.name.isEmpty ? "—" : vm.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: primary.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  (vm.role.isEmpty ? "User" : vm.role).toUpperCase(),
                                                  style: const TextStyle(
                                                    color: primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                vm.username.isEmpty ? "—" : vm.username,
                                                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Divider(color: Colors.black.withOpacity(0.06)),
                                const SizedBox(height: 10),

                                _InfoRow(icon: Icons.email_outlined, text: vm.email.isEmpty ? "—" : vm.email),
                                const SizedBox(height: 8),
                                _InfoRow(icon: Icons.phone_outlined, text: vm.phone.isEmpty ? "—" : vm.phone),
                                const SizedBox(height: 8),
                                _InfoRow(icon: Icons.location_on_outlined, text: vm.address.isEmpty ? "—" : vm.address),
                                const SizedBox(height: 8),
                                _InfoRow(icon: Icons.calendar_today_outlined, text: "Member since ${vm.memberSince}"),

                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openEditProfile(vm),
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                                    label: const Text("Edit Profile", style: TextStyle(color: Colors.black87)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Colors.black.withOpacity(0.10)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // STATS
                          Row(
                            children: [
                              Expanded(child: _StatBox(value: "${vm.visits}", label: "Visits", icon: Icons.person_outline)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatBox(
                                  value: vm.avgRating == 0 ? "—" : vm.avgRating.toStringAsFixed(1),
                                  label: "Avg Rating",
                                  icon: Icons.star_outline,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: _StatBox(value: "${vm.upcoming}", label: "Upcoming", icon: Icons.calendar_month_outlined)),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // SETTINGS LIST
                          _MenuTile(
                            icon: Icons.settings_outlined,
                            title: "Account Settings",
                            subtitle: "Update your personal information",
                            onTap: () => _openEditProfile(vm),
                          ),
                          _MenuTile(
                            icon: Icons.lock_outline,
                            title: "Privacy & Security",
                            subtitle: "Control your privacy settings",
                            onTap: () => _openChangePassword(vm),
                          ),
                          _MenuTile(
                            icon: Icons.notifications_none,
                            title: "Notifications",
                            subtitle: "Manage notification preferences",
                            onTap: () => _snack("Coming soon"),
                          ),
                          _MenuTile(
                            icon: Icons.help_outline,
                            title: "Help & Support",
                            subtitle: "Get help and contact support",
                            onTap: () => _snack("Coming soon"),
                          ),

                          const SizedBox(height: 12),

                          // ABOUT
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black.withOpacity(0.06)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("About QUELESS", style: TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 10),
                                Row(
                                  children: const [
                                    Expanded(child: Text("Version", style: TextStyle(color: Colors.black54))),
                                    Text("1.0.0", style: TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: const [
                                    Expanded(child: Text("Last Updated", style: TextStyle(color: Colors.black54))),
                                    Text("Oct 2024", style: TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text("Terms of Service", style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text("Privacy Policy", style: TextStyle(color: primary, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // LOGOUT
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0x33FF0000)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final ok = await _doubleConfirm(
                                  title1: "Logout?",
                                  msg1: "Do you want to logout from your account?",
                                  title2: "Confirm Logout",
                                  msg2: "Are you sure? You’ll need to login again.",
                                  confirmText: "Logout",
                                );
                                if (!ok) return;

                                await vm.logout();
                                if (!mounted) return;
                                _goToLogin();
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // DELETE ACCOUNT
                          TextButton(
                            onPressed: () async {
                              final ok = await _doubleConfirm(
                                title1: "Delete account?",
                                msg1: "This will permanently delete your account and data.",
                                title2: "Final confirmation",
                                msg2: "This cannot be undone. Delete your account now?",
                                confirmText: "Delete",
                                confirmColor: Colors.red,
                              );
                              if (!ok) return;

                              final err = await vm.deleteMyAccount();
                              if (!mounted) return;

                              if (err != null) {
                                _snack(err);
                                return;
                              }

                              await vm.logout();
                              if (!mounted) return;
                              _snack("Account deleted");
                              _goToLogin();
                            },
                            child: const Text(
                              "Delete Account",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatBox({required this.value, required this.label, required this.icon});

  static const primary = Color(0xFF65BF61);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, color: primary),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const primary = Color(0xFF65BF61);

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
      ),
    );
  }
}
