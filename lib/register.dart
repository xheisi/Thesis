import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'main.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedGender;
  DateTime? _selectedBirthdate;

  final AuthService _authService = AuthService();

  // ✅ Use global language notifier
  String get _language => languageNotifier.value;
  String t(String sq, String en) => _language == 'sq' ? sq : en;

  Future<void> _pickBirthdate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF3A7DFF))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedBirthdate = picked);
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _surnameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _confirmController.text.isEmpty) {
      setState(() => _errorMessage = t('Ju lutem plotësoni fushat e detyrueshme.', 'Please fill in all required fields.'));
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorMessage = t('Fjalëkalimet nuk përputhen.', 'Passwords do not match.'));
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = t('Fjalëkalimi duhet të ketë të paktën 6 karaktere.', 'Password must be at least 6 characters.'));
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    String? error = await _authService.register(
      name: _nameController.text.trim(),
      surname: _surnameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      gender: _selectedGender,
      birthdate: _selectedBirthdate,
    );

    setState(() => _isLoading = false);

    if (error == null) {
      await NotificationService.saveFcmToken();
      await NotificationService.saveToFirestore(
        title: 'Mirësevini në Urbane! 🚌',
        body: 'Llogaria juaj u krijua me sukses. Aplikoni për abone ose blini biletë.',
        type: 'system',
      );
      await _authService.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Llogaria u krijua! Hyni tani.'), backgroundColor: Color(0xFF3A7DFF)));
        Navigator.pop(context);
      }
    } else {
      if (error.contains('email-already-in-use')) {
        setState(() => _errorMessage = t('Ky email është i regjistruar tashmë.', 'This email is already registered.'));
      } else {
        setState(() => _errorMessage = error);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
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
              // ✅ Bus image header — same as login
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.26,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/bus_header.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A3AFF),
                        child: const Center(child: Text('🚌', style: TextStyle(fontSize: 60))),
                      ),
                    ),
                    Container(color: Colors.black.withOpacity(0.35)),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Back button
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                                  ),
                                ),
                                // Language switcher
                                Row(children: [
                                  _LangBall(flag: '🇦🇱', label: 'SQ', selected: lang == 'sq', onTap: () => languageNotifier.value = 'sq'),
                                  const SizedBox(width: 8),
                                  _LangBall(flag: '🇬🇧', label: 'EN', selected: lang == 'en', onTap: () => languageNotifier.value = 'en'),
                                ]),
                              ],
                            ),
                            const Spacer(),
                            Text(t('Krijo Llogari', 'Create Account'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(t('Regjistrohu për të udhëtuar', 'Register to start travelling'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F6FB),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(blurRadius: 15, color: Colors.grey.withOpacity(0.15), offset: const Offset(0, 8))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: _buildLabeledField(label: t('Emri *', 'First Name *'), controller: _nameController, hint: t('Emri', 'First name'), icon: Icons.person_outline)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildLabeledField(label: t('Mbiemri *', 'Last Name *'), controller: _surnameController, hint: t('Mbiemri', 'Last name'), icon: Icons.person_outline)),
                        ]),
                        const SizedBox(height: 16),

                        _buildLabeledField(label: 'Email *', controller: _emailController, hint: t('Shkruaj emailin', 'Enter your email'), icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),

                        _buildLabeledField(
                          label: t('Fjalëkalimi *', 'Password *'),
                          controller: _passwordController,
                          hint: t('Minimum 6 karaktere', 'Minimum 6 characters'),
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 16),

                        _buildLabeledField(
                          label: t('Konfirmo Fjalëkalimin *', 'Confirm Password *'),
                          controller: _confirmController,
                          hint: t('Shkruaj sërish', 'Re-enter password'),
                          icon: Icons.lock_outline,
                          obscure: _obscureConfirm,
                          suffix: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(t('Opsionale', 'Optional'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                          const Expanded(child: Divider()),
                        ]),

                        const SizedBox(height: 16),

                        Text(t('Gjinia', 'Gender'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333355))),
                        const SizedBox(height: 8),
                        Row(children: [
                          _GenderChip(label: t('Mashkull', 'Male'), icon: '👨', selected: _selectedGender == 'male', onTap: () => setState(() => _selectedGender = _selectedGender == 'male' ? null : 'male')),
                          const SizedBox(width: 8),
                          _GenderChip(label: t('Femër', 'Female'), icon: '👩', selected: _selectedGender == 'female', onTap: () => setState(() => _selectedGender = _selectedGender == 'female' ? null : 'female')),
                        ]),

                        const SizedBox(height: 16),

                        Text(t('Datëlindja', 'Date of Birth'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333355))),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _pickBirthdate,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _selectedBirthdate != null ? const Color(0xFF3A7DFF) : Colors.transparent, width: 1.5),
                            ),
                            child: Row(children: [
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFF3A7DFF), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedBirthdate != null ? DateFormat('dd/MM/yyyy').format(_selectedBirthdate!) : t('Zgjidh datën', 'Select date'),
                                style: TextStyle(color: _selectedBirthdate != null ? const Color(0xFF333355) : Colors.grey, fontSize: 14),
                              ),
                            ]),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                            child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3A7DFF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 3,
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text(t('Regjistrohu', 'Register'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: RichText(
                              text: TextSpan(
                                text: t('Keni një llogari? ', 'Already have an account? '),
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                                children: [TextSpan(text: t('Hyr', 'Login'), style: const TextStyle(color: Color(0xFF3A7DFF), fontWeight: FontWeight.bold))],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabeledField({required String label, required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix, TextInputType? keyboardType}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333355))),
      const SizedBox(height: 6),
      TextField(
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
      ),
    ]);
  }
}

class _GenderChip extends StatelessWidget {
  final String label, icon;
  final bool selected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3A7DFF) : const Color(0xFFF8FAFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF3A7DFF) : Colors.grey.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey.shade700)),
        ]),
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