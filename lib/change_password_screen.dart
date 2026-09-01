import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shown to staff (line_admin, faturino) after first login so they can
/// replace their temporary password with something personal.
class ChangePasswordScreen extends StatefulWidget {
  /// Pass true if this is a forced first-time setup (hides back button).
  final bool isFirstTime;
  const ChangePasswordScreen({super.key, this.isFirstTime = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() { _error = null; _success = false; });

    if (_currentCtrl.text.isEmpty || _newCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      setState(() => _error = 'Ju lutem plotësoni të gjitha fushat.');
      return;
    }
    if (_newCtrl.text.length < 8) {
      setState(() => _error = 'Fjalëkalimi i ri duhet të ketë të paktën 8 karaktere.');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Fjalëkalimet nuk përputhen.');
      return;
    }
    if (_newCtrl.text == _currentCtrl.text) {
      setState(() => _error = 'Fjalëkalimi i ri duhet të jetë i ndryshëm nga ai aktual.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;

      // Re-authenticate with current password first
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);

      // Now update
      await user.updatePassword(_newCtrl.text);

      setState(() { _isLoading = false; _success = true; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fjalëkalimi u ndryshua me sukses ✓'),
          backgroundColor: Color(0xFF00C853),
        ));
        // Small delay then pop
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          _error = 'Fjalëkalimi aktual është i gabuar.';
        } else if (e.code == 'weak-password') {
          _error = 'Fjalëkalimi i ri është shumë i dobët.';
        } else {
          _error = 'Gabim: ${e.message}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: widget.isFirstTime
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: BackButton(color: const Color(0xFF1A1A2E)),
              title: const Text('Ndrysho fjalëkalimin',
                  style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 16)),
              centerTitle: true,
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            if (widget.isFirstTime) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Color(0xFFFFA000)),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'Ju lutem ndryshoni fjalëkalimin e përkohshëm para se të vazhdoni.',
                    style: TextStyle(color: Color(0xFFFFA000), fontWeight: FontWeight.w600, fontSize: 13),
                  )),
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // Icon
            Center(child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_reset, color: Colors.white, size: 36),
            )),
            const SizedBox(height: 20),

            Center(child: Text(
              widget.isFirstTime ? 'Vendosni fjalëkalimin tuaj' : 'Ndrysho fjalëkalimin',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            )),
            const SizedBox(height: 6),
            const Center(child: Text(
              'Fjalëkalimi duhet të ketë të paktën 8 karaktere',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            )),
            const SizedBox(height: 32),

            // Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16)],
              ),
              child: Column(children: [

                _PasswordField(
                  controller: _currentCtrl,
                  label: 'Fjalëkalimi aktual (i përkohshëm)',
                  obscure: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
                const SizedBox(height: 14),

                _PasswordField(
                  controller: _newCtrl,
                  label: 'Fjalëkalimi i ri',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                ),
                const SizedBox(height: 14),

                _PasswordField(
                  controller: _confirmCtrl,
                  label: 'Konfirmo fjalëkalimin e ri',
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A7DFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Ruaj fjalëkalimin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _PasswordField({required this.controller, required this.label, required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF3A7DFF), size: 20),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3A7DFF), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
