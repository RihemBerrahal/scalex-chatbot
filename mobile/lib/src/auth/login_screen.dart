import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:scalex_chat/src/auth/signup_screen.dart';
import '../core/api.dart';
import 'auth_repo.dart';
import '../chat/chat_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    Api.I.install();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _auth() async {
    // ✅ stop immediately if invalid
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      final repo = AuthRepo();
      await repo.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } catch (e) {
      print('Login error: $e');
      final msg = e.toString().tr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFFe74c3c)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF2c2c2c);
    const green = Color(0xFF32a94d);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'app_name'.tr(),
          style: const TextStyle(
            color: dark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DropdownButton<Locale>(
              underline: const SizedBox.shrink(),
              value: context.locale,
              items: const [
                DropdownMenuItem(value: Locale('en'), child: Text('English')),
                DropdownMenuItem(value: Locale('ar'), child: Text('العربية')),
              ],
              onChanged: (l) => context.setLocale(l!),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                        height: 80,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'welcome_back'.tr(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'sign_in_to_continue'.tr(),
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                const SizedBox(height: 8),
                _LabeledField(
                  label: 'email'.tr(),
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('enter_email'.tr()),
                    style: const TextStyle(color: dark),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'email_required'.tr();
                      final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(t);
                      if (!ok) return 'invalid_email_format'.tr();
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Password
                const SizedBox(height: 8),
                _LabeledField(
                  label: 'password'.tr(),
                  child: TextFormField(
                    controller: _pass,
                    obscureText: _obscurePassword,
                    decoration: _inputDecoration('enter_password'.tr())
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                    style: const TextStyle(color: dark),
                    validator: (v) {
                      final t = v ?? '';
                      if (t.isEmpty) return 'password_required'.tr();
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _auth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      disabledBackgroundColor: green.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'login'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'dont_have_account'.tr(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Turns Dio/server errors into friendly, localized strings.
  String _prettyAuthError(Object e, BuildContext ctx) {
    // If Dio throws
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      final msg = (data is Map ? (data['error'] ?? data['message']) : null)
          ?.toString();

      if (code == 404)
        return 'account_not_found'.tr(); // backend: "Account not found"
      print('Auth error: $code, message: $msg');
      if (code == 401)
        return 'incorrect_password'.tr(); // backend: "Incorrect password"
      if (code == 400) {
        // show server’s validation message if present (e.g., "Invalid email format • Password is required")
        if (msg != null && msg.isNotEmpty) return msg;
        return 'invalid_credentials'.tr();
      }
      if (msg != null && msg.isNotEmpty) return msg;
      return 'invalid_credentials'.tr();
    }

    // If AuthRepo throws a plain string
    final s = e.toString();
    if (s.isNotEmpty && s != 'Exception') return s;
    return 'invalid_credentials'.tr();
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
        borderSide: BorderSide(color: Colors.grey[300]!),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
