import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/profile_viewmodel.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _current = TextEditingController();
  final _newPass = TextEditingController();
  final _confirm = TextEditingController();

  bool _ob1 = true;
  bool _ob2 = true;
  bool _ob3 = true;

  @override
  void dispose() {
    _current.dispose();
    _newPass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _newVal(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (s.length < 6) return 'Min 6 characters';
    return null;
  }

  String? _confirmVal(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Required';
    if (v!.trim() != _newPass.text.trim()) return 'Passwords do not match';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: const Color(0xFF7CD39A),
        elevation: 0,
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _current,
                    validator: _req,
                    obscureText: _ob1,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _ob1 = !_ob1),
                        icon: Icon(_ob1 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPass,
                    validator: _newVal,
                    obscureText: _ob2,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _ob2 = !_ob2),
                        icon: Icon(_ob2 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    validator: _confirmVal,
                    obscureText: _ob3,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _ob3 = !_ob3),
                        icon: Icon(_ob3 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: vm.isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;

                              final ok = await context.read<ProfileViewModel>().changePassword(
                                    currentPassword: _current.text.trim(),
                                    newPassword: _newPass.text.trim(),
                                  );

                              if (!context.mounted) return;

                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password changed')),
                                );
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(vm.error ?? 'Password change failed')),
                                );
                              }
                            },
                      child: vm.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
