import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../core/api.dart';
import 'auth_repo.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showPass = false;
  bool _showConfirm = false;

  @override
  void initState() {
    super.initState();
    // ensure Dio interceptor (JWT) is installed
    Api.I.install();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AuthRepo().signup(_email.text.trim(), _pass.text);
      if (!mounted) return;
      // After signup, go to login or directly to chat screen if you prefer.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('account_created'.tr())),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFe74c3c),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF32a94d);
    const dark = Color(0xFF2c2c2c);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          'signup'.tr(),
          style: const TextStyle(color: dark, fontWeight: FontWeight.bold),
        ),
        actions: [
          // quick language toggle
          DropdownButton<Locale>(
            underline: const SizedBox.shrink(),
            value: context.locale,
            items: const [
              DropdownMenuItem(value: Locale('en'), child: Text('English')),
              DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
            ],
            onChanged: (l) => context.setLocale(l!),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('create_account'.tr(),
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, color: dark)),
                const SizedBox(height: 6),
                Text('sign_in_to_continue'.tr(),
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 24),

                // Email
                _LabeledField(
                  label: 'email'.tr(),
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('email'.tr()),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'required'.tr();
                      // very light email check
                      if (!t.contains('@') || !t.contains('.')) {
                        return 'invalid_email'.tr();
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                _LabeledField(
                  label: 'password'.tr(),
                  child: TextFormField(
                    controller: _pass,
                    obscureText: !_showPass,
                    decoration: _inputDecoration('password'.tr()).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                    ),
                    validator: (v) {
                      final t = v ?? '';
                      if (t.isEmpty) return 'required'.tr();
                      if (t.length < 6) return 'min_chars'.tr(args: ['6']);
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm Password
                _LabeledField(
                  label: 'confirm_password'.tr(),
                  child: TextFormField(
                    controller: _confirm,
                    obscureText: !_showConfirm,
                    decoration: _inputDecoration('confirm_password'.tr()).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                    validator: (v) {
                      final t = v ?? '';
                      if (t.isEmpty) return 'required'.tr();
                      if (t != _pass.text) return 'passwords_do_not_match'.tr();
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('signup'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 12),

                // Already have an account? Login
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'already_have_account'.tr(), style: TextStyle(color: Colors.grey[700])),
                    const TextSpan(text: '  '),
                    TextSpan(text: 'login'.tr(), style: const TextStyle(color: green, fontWeight: FontWeight.w600)),
                  ])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFf8f9fa),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF32a94d), width: 1.3),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      child,
    ]);
  }
}
