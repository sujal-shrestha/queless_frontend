import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isStaff = false; // false = User, true = Staff

  final _userFormKey = GlobalKey<FormState>();
  final _staffFormKey = GlobalKey<FormState>();

  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _userPasswordController = TextEditingController();

  final TextEditingController _staffIdController = TextEditingController();
  final TextEditingController _staffPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText; // ✅ inline error

  @override
  void dispose() {
    _userIdController.dispose();
    _userPasswordController.dispose();
    _staffIdController.dispose();
    _staffPasswordController.dispose();
    super.dispose();
  }

  void _switchRole(bool staff) {
    setState(() {
      isStaff = staff;
      _errorText = null; // ✅ clear error when switching
    });
  }

  String? _validateId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'ID is required';

    // ✅ Username rule (same as backend): 3-20 chars letters/numbers/_/-
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_-]{3,20}$');
    if (!usernameRegex.hasMatch(v)) {
      return 'Invalid ID format';
    }

    // ✅ Optional: Enforce prefix for your UI (S... for user, ST... for staff)
    if (!isStaff && !v.startsWith('S')) {
      return 'User ID should start with "S" (e.g., S2024001)';
    }
    if (isStaff && !v.startsWith('ST')) {
      return 'Staff ID should start with "ST" (e.g., ST2024001)';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'At least 6 characters';
    return null;
  }

  Future<void> _onLogin() async {
    final formKey = isStaff ? _staffFormKey : _userFormKey;
    if (!formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final id = isStaff ? _staffIdController.text.trim() : _userIdController.text.trim();
    final password = isStaff
        ? _staffPasswordController.text.trim()
        : _userPasswordController.text.trim();
    final role = isStaff ? 'staff' : 'user';

    final result = await ApiService.login(id: id, password: password, role: role);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result['success'] == true) {
      // ✅ optional: clear error + go home
      setState(() => _errorText = null);
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // ✅ inline error (looks cleaner than SnackBar for login)
      setState(() {
        _errorText = result['message'] ?? 'Login failed';
      });

      // still show snackbar if you want (optional)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Login failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Green header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF18C964), Color(0xFF11A94A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.monitor_heart_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Queless',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Smart Queue & Appointment',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Feature chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _FeatureChip(icon: Icons.timer_outlined, label: 'Reduced Wait'),
                      _FeatureChip(icon: Icons.event_available_outlined, label: 'Easy Booking'),
                      _FeatureChip(icon: Icons.query_stats_outlined, label: 'Live Queue'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // White card with tabs & form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // segmented tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchRole(false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: isStaff ? Colors.transparent : Colors.white,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isStaff ? Colors.grey[600] : primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _switchRole(true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: isStaff ? Colors.white : Colors.transparent,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Staff',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isStaff ? primary : Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        isStaff ? 'Staff Login' : 'User Login',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isStaff
                            ? 'Enter your staff ID to access QUELESS'
                            : 'Enter your student ID to access Queless',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // ✅ Inline error message
                      if (_errorText != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Form(
                        key: isStaff ? _staffFormKey : _userFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(isStaff ? 'Staff ID' : 'User ID', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: isStaff ? _staffIdController : _userIdController,
                              decoration: InputDecoration(
                                hintText: isStaff ? 'e.g., ST2024001' : 'e.g., S2024001',
                              ),
                              validator: _validateId,
                              onChanged: (_) {
                                if (_errorText != null) setState(() => _errorText = null);
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text('Password', style: TextStyle(fontSize: 13)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: isStaff ? _staffPasswordController : _userPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(hintText: 'Enter your password'),
                              validator: _validatePassword,
                              onChanged: (_) {
                                if (_errorText != null) setState(() => _errorText = null);
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _isLoading ? null : _onLogin,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(isStaff ? 'Login as Staff' : 'Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // signup link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ", style: TextStyle(fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/signup'),
                            child: Text(
                              'Sign up',
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Need help? Contact support@queless.com',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
