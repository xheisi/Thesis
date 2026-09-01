import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'register.dart';
import 'home.dart';
import 'admin_home.dart';
import 'faturino_home.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  final AuthService _authService = AuthService();

  // ✅ Use global language notifier
  String get _language => languageNotifier.value;
  String t(String sq, String en) => _language == 'sq' ? sq : en;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = t('Ju lutem plotësoni të gjitha fushat.', 'Please fill in all fields.'));
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    final error = await _authService.login(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (error == null) {
      final role = await _authService.getUserRole();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => (role == 'line_admin' || role == 'super_admin')
              ? const AdminHomePage()
              : role == 'faturino'
                  ? const FatorinoHomePage()
                  : const HomePage(),
        ));
      }
    } else if (error == 'inactive') {
      setState(() => _errorMessage = t(
        'Llogaria juaj është çaktivizuar. Kontaktoni administratorin.',
        'Your account has been deactivated. Contact your administrator.',
      ));
    } else if (error.contains('wrong-password') || error.contains('invalid-credential') || error.contains('user-not-found') || error.contains('INVALID_LOGIN_CREDENTIALS')) {
      setState(() => _errorMessage = t('Email ose fjalëkalimi gabim.', 'Wrong email or password.'));
    } else {
      setState(() => _errorMessage = error);
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(t('Rivendos fjalëkalimin', 'Reset password'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t("Shkruani emailin tuaj dhe do t'ju dërgojmë një link.", "Enter your email and we'll send you a reset link."),
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 16),
          TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t('Anulo', 'Cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A7DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(dialogContext);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(t('Link-u u dërgua! Kontrolloni emailin tuaj.', 'Reset link sent! Check your email.')),
                  backgroundColor: const Color(0xFF00C853),
                ));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(t('Email nuk u gjet.', 'Email not found.')),
                  backgroundColor: Colors.red,
                ));
              }
            },
            child: Text(t('Dërgo', 'Send'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF1A3AFF),
          body: Column(
            children: [
              // ✅ Bus image header — full width, takes top ~35% of screen
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.34,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ✅ Replace this with your bus image — put it at assets/images/bus_header.png
                    Image.asset(
                      'assets/images/bus_header.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A3AFF),
                        child: const Center(child: Text('🚌', style: TextStyle(fontSize: 80))),
                      ),
                    ),
                    // Dark overlay so text is readable
                    Container(color: Colors.black.withOpacity(0.35)),
                    // URBANE title over image
                    SafeArea(
                      child: Column(
                        children: [
                          // Language switcher top right
                          Padding(
                            padding: const EdgeInsets.only(top: 12, right: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _LangBall(flag: '🇦🇱', label: 'SQ', selected: lang == 'sq', onTap: () => languageNotifier.value = 'sq'),
                                const SizedBox(width: 8),
                                _LangBall(flag: '🇬🇧', label: 'EN', selected: lang == 'en', onTap: () => languageNotifier.value = 'en'),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const Text('URBANE', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3)),
                          Text(t('Transporti Urban i Tiranës', 'Urban Transport of Tirana'),
                              style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ White rounded card below image
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F6FB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(blurRadius: 15, color: Colors.grey.withOpacity(0.15), offset: const Offset(0, 8))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t('Hyr në llogarinë tënde', 'Login to your account'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3A7DFF))),
                          const SizedBox(height: 20),

                          _buildField(controller: _emailController, hint: 'Email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 14),

                          _buildField(
                            controller: _passwordController,
                            hint: t('Fjalëkalimi', 'Password'),
                            icon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: 6),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(10, 36)),
                              child: Text(t('Keni harruar fjalëkalimin?', 'Forgot password?'),
                                  style: const TextStyle(color: Color(0xFF3A7DFF), fontSize: 13)),
                            ),
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                              child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 4),

                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3A7DFF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : Text(t('Hyr', 'Login'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                              child: RichText(
                                text: TextSpan(
                                  text: t('Nuk keni një llogari? ', "Don't have an account? "),
                                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                                  children: [TextSpan(text: t('Regjistrohu', 'Register'), style: const TextStyle(color: Color(0xFF3A7DFF), fontWeight: FontWeight.bold))],
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF3A7DFF), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A7DFF), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _LangBall extends StatelessWidget {
  final String flag, label;
  final bool selected;
  final VoidCallback onTap;
  const _LangBall({required this.flag, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF3A7DFF) : Colors.white)),
        ]),
      ),
    );
  }
}