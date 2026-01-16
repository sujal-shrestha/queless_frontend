import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/profile_viewmodel.dart';
import '../auth/auth_screen.dart';

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
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  void _goToAuth() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = Colors.red,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return ok == true;
  }

  InputDecoration _fieldDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF6F7F9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  String _prettyRole(String raw) {
    final r = raw.trim();
    if (r.isEmpty) return "Member";
    final lower = r.toLowerCase();
    if (lower == "user") return "Member";
    if (lower == "customer") return "Member";
    if (lower == "staff") return "Staff";
    if (lower == "admin") return "Admin";
    // Capitalize first letter
    return "${r[0].toUpperCase()}${r.substring(1)}";
  }

  Future<void> _openEditProfile(ProfileViewModel vm) async {
    final nameC = TextEditingController(text: vm.name);
    final emailC = TextEditingController(text: vm.email);

    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Account Settings",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: nameC,
                    decoration: _fieldDeco("Full Name", icon: Icons.person_outline),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailC,
                    decoration: _fieldDeco("Email", icon: Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameC.text.trim();
                              final email = emailC.text.trim();

                              if (name.isEmpty) {
                                _snack("Name is required");
                                return;
                              }
                              if (email.isEmpty || !email.contains("@")) {
                                _snack("Enter a valid email");
                                return;
                              }

                              setSheetState(() => saving = true);

                              // ✅ Keep call compatible with your existing ViewModel
                              final err = await vm.updateMyProfile(
                                name: name,
                                email: email,
                                phone: "",     // removed from UI
                                address: "",   // removed from UI
                              );

                              if (!mounted) return;
                              setSheetState(() => saving = false);

                              if (err == null) {
                                Navigator.pop(ctx);
                                _snack("Profile updated");
                              } else {
                                _snack(err);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openChangePassword(ProfileViewModel vm) async {
    final currentC = TextEditingController();
    final newC = TextEditingController();
    final confirmC = TextEditingController();

    bool saving = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

            InputDecoration decoPwd(String label, bool visible, VoidCallback toggle) {
              return _fieldDeco(label, icon: Icons.lock_outline).copyWith(
                suffixIcon: IconButton(
                  onPressed: toggle,
                  icon: Icon(visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Privacy & Security",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        onPressed: saving ? null : () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: currentC,
                    decoration: decoPwd("Current Password", showCurrent, () {
                      setSheetState(() => showCurrent = !showCurrent);
                    }),
                    obscureText: !showCurrent,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newC,
                    decoration: decoPwd("New Password", showNew, () {
                      setSheetState(() => showNew = !showNew);
                    }),
                    obscureText: !showNew,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmC,
                    decoration: decoPwd("Confirm New Password", showConfirm, () {
                      setSheetState(() => showConfirm = !showConfirm);
                    }),
                    obscureText: !showConfirm,
                    textInputAction: TextInputAction.done,
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final newP = newC.text.trim();
                              final confirmP = confirmC.text.trim();

                              if (currentC.text.isEmpty) {
                                _snack("Enter your current password");
                                return;
                              }
                              if (newP.length < 6) {
                                _snack("New password must be at least 6 characters");
                                return;
                              }
                              if (newP != confirmP) {
                                _snack("New passwords do not match");
                                return;
                              }

                              setSheetState(() => saving = true);

                              final err = await vm.changeMyPassword(
                                currentPassword: currentC.text,
                                newPassword: newC.text,
                              );

                              if (!mounted) return;
                              setSheetState(() => saving = false);

                              if (err == null) {
                                Navigator.pop(ctx);
                                _snack("Password updated");
                              } else {
                                _snack(err);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              "Update Password",
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openSimplePage({required Widget page}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();

    final displayRole = _prettyRole(vm.role);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: vm.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: const BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (Navigator.canPop(context)) Navigator.pop(context);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
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
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => context.read<ProfileViewModel>().load(),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (vm.error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.red.withOpacity(0.2)),
                              ),
                              child: Text(vm.error!, style: const TextStyle(color: Colors.red)),
                            ),

                          // Profile card
                          _Card(
                            child: Column(
                              children: [
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
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: primary.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  displayRole.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  vm.username.isEmpty ? "—" : vm.username,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
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
                                _InfoRow(icon: Icons.calendar_today_outlined, text: "Member since ${vm.memberSince}"),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Quick stats
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

                          const SizedBox(height: 16),

                          const Text("Settings", style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),

                          _ActionTile(
                            icon: Icons.manage_accounts_outlined,
                            title: "Account Settings",
                            subtitle: "Edit name and email",
                            onTap: () => _openEditProfile(vm),
                          ),
                          const SizedBox(height: 10),
                          _ActionTile(
                            icon: Icons.lock_outline,
                            title: "Change Password",
                            subtitle: "Update your password securely",
                            onTap: () => _openChangePassword(vm),
                          ),

                          const SizedBox(height: 16),

                          _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("About", style: TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 10),
                                _KVRow(k: "Version", v: "1.0.0"),
                                const SizedBox(height: 6),
                                _KVRow(k: "Last Updated", v: "Oct 2024"),
                                const SizedBox(height: 10),
                                Divider(color: Colors.black.withOpacity(0.06)),
                                _LinkTile(
                                  title: "Terms of Service",
                                  onTap: () => _openSimplePage(page: const TermsOfServicePage()),
                                ),
                                _LinkTile(
                                  title: "Privacy Policy",
                                  onTap: () => _openSimplePage(page: const PrivacyPolicyPage()),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Logout
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text(
                                "Logout",
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.withOpacity(0.25)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () async {
                                final ok = await _confirm(
                                  title: "Logout?",
                                  message: "You’ll need to login again.",
                                  confirmText: "Logout",
                                  confirmColor: Colors.red,
                                );
                                if (!ok) return;

                                try {
                                  await vm.logout();
                                  if (!mounted) return;
                                  _goToAuth();
                                } catch (e) {
                                  if (!mounted) return;
                                  _snack("Logout failed: $e");
                                }
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Delete account
                          TextButton(
                            onPressed: () async {
                              final ok = await _confirm(
                                title: "Delete account?",
                                message: "This will permanently delete your account and data.",
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

                              try {
                                await vm.logout();
                              } catch (_) {}
                              if (!mounted) return;

                              _snack("Account deleted");
                              _goToAuth();
                            },
                            child: const Text(
                              "Delete Account",
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
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

// ---------- UI components ----------

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const primary = Color(0xFF65BF61);

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String k;
  final String v;
  const _KVRow({required this.k, required this.v});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _LinkTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: onTap,
    );
  }
}

// ---------- Simple pages ----------

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});
  static const primary = Color(0xFF65BF61);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("Terms of Service"),
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: _LegalBody(
          title: "Terms of Service",
          body:
              "These Terms of Service explain how you can use QUELESS.\n\n"
              "• Use the app responsibly and follow local rules.\n"
              "• Do not misuse the service, attempt unauthorized access, or disrupt the system.\n"
              "• We may update features and policies over time.\n\n"
              "If you have questions, contact support through your organization/admin.",
        ),
      ),
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});
  static const primary = Color(0xFF65BF61);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        title: const Text("Privacy Policy"),
        elevation: 0,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: _LegalBody(
          title: "Privacy Policy",
          body:
              "This Privacy Policy explains what data QUELESS may store to operate the app.\n\n"
              "• Account info (like name/email) is used for login and profile.\n"
              "• Booking/queue activity is stored to provide history and service.\n"
              "• We don’t sell personal data.\n\n"
              "You can request account deletion from the Profile screen.",
        ),
      ),
    );
  }
}

class _LegalBody extends StatelessWidget {
  final String title;
  final String body;
  const _LegalBody({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(color: Colors.black87, height: 1.35, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
