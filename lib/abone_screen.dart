import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AboneScreen extends StatefulWidget {
  const AboneScreen({super.key});

  @override
  State<AboneScreen> createState() => _AboneScreenState();
}

class _AboneScreenState extends State<AboneScreen> {
  String? _selectedCategory;
  File? _idPhoto;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Map<String, DateTime> _getMonthValidity() {
    final now = DateTime.now();
    return {
      'from': DateTime(now.year, now.month, 1),
      'until': DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    };
  }

  int _priceForCategory(String category) {
    if (category == 'student') return 0;
    if (category == 'elderly') return 800;
    return 1600;
  }

  String _categoryTitle(String category) {
    if (category == 'student') return 'Abone Studentore';
    if (category == 'elderly') return 'Abone Senior';
    return 'Abone Gjenerale';
  }

  Future<void> _pickPhoto() async {
    if (_isLoading) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF3A7DFF)),
              title: const Text('Kamera'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 75);
                if (picked != null && mounted) setState(() => _idPhoto = File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF3A7DFF)),
              title: const Text('Galeria'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                if (picked != null && mounted) setState(() => _idPhoto = File(picked.path));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadVerificationImage({required String userId, required String requestId}) async {
    final file = _idPhoto;
    if (file == null) throw Exception('Nuk është zgjedhur asnjë foto.');

    final ref = _storage.ref().child('verification_documents/$userId/$requestId.jpg');
    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    if (uploadTask.state != TaskState.success) {
      throw Exception('Ngarkimi i fotos dështoi.');
    }

    return ref.getDownloadURL();
  }

  Future<void> _submitForVerification() async {
    final category = _selectedCategory;
    final user = _auth.currentUser;

    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zgjidhni një kategori abone.')),
      );
      return;
    }

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duhet të jeni të loguar.')),
      );
      return;
    }

    if (_idPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ju lutem ngarkoni foton e dokumentit për verifikim.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final validity = _getMonthValidity();
      final requestRef = _db.collection('abonements').doc();
      final imageUrl = await _uploadVerificationImage(userId: user.uid, requestId: requestRef.id);
      final price = _priceForCategory(category);

      await requestRef.set({
        'user_id': user.uid,
        'user_email': user.email ?? userData['email'] ?? '',
        'user_name': userData['name'] ?? '',
        'user_surname': userData['surname'] ?? '',
        'category': category,
        'category_label': _categoryTitle(category),
        'status': 'pending_verification',
        'payment_status': category == 'student' ? 'not_required' : 'waiting_admin_approval',
        'price_due': price,
        'price_paid': 0,
        'valid_from': Timestamp.fromDate(validity['from']!),
        'valid_until': Timestamp.fromDate(validity['until']!),
        'verification_image_url': imageUrl,
        'verified_by': null,
        'verified_at': null,
        'rejection_reason': null,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'renewal_count': 0,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aplikimi u dërgua për verifikim. Statusi: në pritje.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gabim gjatë dërgimit: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTitle = _selectedCategory == null ? 'dokumentit' : _categoryTitle(_selectedCategory!);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: _isLoading ? null : () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF3A7DFF)),
          ),
        ),
        title: const Text('Bli Abone', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zgjidh kategorinë', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Së pari dërgohet dokumenti për verifikim nga administratori. Pagesa bëhet vetëm pasi aplikimi aprovohet.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),
            _AboneOption(
              emoji: '🎫',
              title: 'Abone Gjenerale',
              subtitle: 'Kërkon verifikim dokumenti, pastaj pagesë',
              price: '1,600 Lekë / muaj',
              color: const Color(0xFF3A7DFF),
              selected: _selectedCategory == 'general',
              onTap: () => setState(() => _selectedCategory = 'general'),
            ),
            const SizedBox(height: 12),
            _AboneOption(
              emoji: '🎓',
              title: 'Abone Studentore',
              subtitle: 'Falas pas aprovimit nga administratori',
              price: 'Falas',
              color: const Color(0xFF00C853),
              selected: _selectedCategory == 'student',
              onTap: () => setState(() => _selectedCategory = 'student'),
            ),
            const SizedBox(height: 12),
            _AboneOption(
              emoji: '👴',
              title: 'Abone Senior',
              subtitle: 'Kërkon verifikim dokumenti, pastaj pagesë',
              price: '800 Lekë / muaj',
              color: const Color(0xFFFF6D00),
              selected: _selectedCategory == 'elderly',
              onTap: () => setState(() => _selectedCategory = 'elderly'),
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(height: 28),
              Text('Foto e $selectedTitle', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Ngarko foto të qartë të dokumentit. Ajo ruhet në Firebase Storage dhe statusi ruhet në Firestore si pending_verification.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _idPhoto != null ? const Color(0xFF3A7DFF) : Colors.grey.shade300, width: 2),
                  ),
                  child: _idPhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(_idPhoto!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 38, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('Kliko për të ngarkuar foton', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                ),
              ),
              if (_idPhoto != null)
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Ndrysho foton'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF3A7DFF)),
                ),
            ],
            const SizedBox(height: 32),
            if (_selectedCategory != null)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7DFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Dërgo për Verifikim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AboneOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String price;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AboneOption({required this.emoji, required this.title, required this.subtitle, required this.price, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                if (selected) Icon(Icons.check_circle, color: color, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
