import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'abone_screen.dart';
import 'qr_screen.dart';
import 'main.dart';
import 'services/auth_service.dart';
import 'services/payment_service.dart';
import 'notifications_screen.dart';
import 'map_screen.dart';
import 'ticket_screen.dart';
import 'services/notification_service.dart';
import 'chatbot_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    _HomeTab(),
    _TicketsTab(),
    _MapTab(),
    _ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FB),
      body: Stack(
        children: [
          _tabs[_currentIndex],
          const ChatbotFloatingButton(isAdmin: false),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF3A7DFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_outlined), activeIcon: Icon(Icons.confirmation_number), label: 'Bileta'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Harta'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profili'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HOME TAB — only abone card + buy ticket button
// ─────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

  // Returns time-aware greeting in Albanian
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Mirëmëngjes';
    if (hour >= 12 && hour < 17) return 'Mirëdita';
    if (hour >= 17 && hour < 21) return 'Mirëmbrëma';
    return 'Përshëndetje';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                String name = 'Pasagjer';
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  name = data['name'] ?? 'Pasagjer';
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ✅ FIX 1: Time-aware greeting, no emoji
                        Text(_greeting(), style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                      ],
                    ),
                    UnreadNotifBadge(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: const Color(0xFF3A7DFF), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Abone section ──
            _PassengerAboneSection(userId: user?.uid),

            const SizedBox(height: 16),

            // ── Buy Ticket button — same size as abone card ──
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketScreen())),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF00B894), Color(0xFF00856F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF00B894).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('URBANE', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: const Text('50 Lekë', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    const Text('Bli Biletë', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Vlen 1 orë • Të gjitha linjat', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('🎫 Biletë e vetme', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, color: Color(0xFF00B894), size: 14),
                          SizedBox(width: 4),
                          Text('Bli Tani', style: TextStyle(color: Color(0xFF00B894), fontWeight: FontWeight.bold, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ],
                ),
              ),
            ),

            // ✅ FIX 3: No "Udhëtimet e Fundit" section here anymore
            // Trip history is only in the Bileta tab
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ABONE SECTION (unchanged — working great)
// ─────────────────────────────────────────────
class _PassengerAboneSection extends StatefulWidget {
  final String? userId;
  const _PassengerAboneSection({required this.userId});

  @override
  State<_PassengerAboneSection> createState() => _PassengerAboneSectionState();
}

class _PassengerAboneSectionState extends State<_PassengerAboneSection> {
  bool _isPaying = false;

  int _priceFor(String category, Map<String, dynamic> data) {
    final storedPrice = data['price_due'];
    if (storedPrice is int) return storedPrice;
    if (storedPrice is num) return storedPrice.toInt();
    if (category == 'elderly') return 800;
    if (category == 'student') return 0;
    return 1600;
  }

  Future<void> _payApprovedAbone(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final category = data['category'] ?? 'general';
    final price = _priceFor(category, data);

    setState(() => _isPaying = true);

    final success = await PaymentService.processPayment(
      context: context,
      amount: price,
      description: 'Pagesë abone ${_categoryLabel(category)}',
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pagesa dështoi ose u anulua.'), backgroundColor: Colors.red),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('abonements').doc(doc.id).update({
      'status': 'active',
      'payment_status': 'paid',
      'price_paid': price,
      'paid_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    setState(() => _isPaying = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pagesa u krye. Abonja u aktivizua ✓'), backgroundColor: Color(0xFF00C853)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    if (userId == null) return const _NoAboneCard(onBuyAbone: null);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('abonements').where('user_id', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        docs.sort((a, b) {
          final ad = (a.data() as Map<String, dynamic>)['created_at'];
          final bd = (b.data() as Map<String, dynamic>)['created_at'];
          if (ad is Timestamp && bd is Timestamp) return bd.compareTo(ad);
          return 0;
        });

        DocumentSnapshot? active;
        DocumentSnapshot? approved;
        DocumentSnapshot? pending;
        DocumentSnapshot? rejected;

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'];
          if (status == 'active' && active == null) active = doc;
          if (status == 'approved_for_payment' && approved == null) approved = doc;
          if (status == 'pending_verification' && pending == null) pending = doc;
          if (status == 'rejected' && rejected == null) rejected = doc;
        }

        if (active != null) {
          final data = active.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'general';
          final validUntil = (data['valid_until'] as Timestamp?)?.toDate();
          final validUntilStr = validUntil != null ? '${validUntil.day}/${validUntil.month}/${validUntil.year}' : '-';
          final ownerName = '${data['user_name'] ?? ''} ${data['user_surname'] ?? ''}'.trim();
          final capturedId = active.id;
          return _AboneCard(
            label: 'Abone ${_categoryLabel(category)}',
            validUntil: validUntilStr,
            onShowQR: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QRScreen(
                  aboneId: capturedId,
                  categoryLabel: _categoryLabel(category),
                  validUntil: validUntilStr,
                  ownerName: ownerName.isNotEmpty ? ownerName : userId,
                ),
              ),
            ),
          );
        }

        if (approved != null) {
          final data = approved.data() as Map<String, dynamic>;
          final category = data['category'] ?? 'general';
          final price = _priceFor(category, data);
          return _ApprovedForPaymentCard(
            categoryLabel: _categoryLabel(category),
            price: price,
            isPaying: _isPaying,
            onPay: () => _payApprovedAbone(context, approved!),
          );
        }

        if (pending != null) return const _PendingAboneCard();
        if (rejected != null) return const _RejectedAboneCard();

        return _NoAboneCard(
          onBuyAbone: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboneScreen())),
        );
      },
    );
  }

  String _categoryLabel(String category) {
    if (category == 'student') return 'Studentore';
    if (category == 'elderly') return 'Senior';
    return 'Gjenerale';
  }
}

// ─────────────────────────────────────────────
// TICKETS TAB
// ✅ FIX 4: Shows scan history per ticket (each scan = one trip record)
// ─────────────────────────────────────────────
class _TicketsTab extends StatelessWidget {
  const _TicketsTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historiku i Udhëtimeve', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Çdo skanim = një udhëtim', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('validations')
                    .where('user_id', isEqualTo: user?.uid)
                    .orderBy('validated_at', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🚌', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 16),
                          const Text('Nuk keni udhëtime', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Udhëtimet tuaja do të shfaqen këtu pas skanimit', style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      final t = (data['validated_at'] as Timestamp?)?.toDate();
                      final dateStr = t != null ? '${t.day}/${t.month}/${t.year}  ${t.hour}:${t.minute.toString().padLeft(2, '0')}' : '-';
                      final lineName = data['line_name'] ?? 'Linjë e panjohur';
                      final stationName = data['station_name'] ?? '';
                      final type = data['type'] ?? 'ticket';
                      final isAbone = type == 'abone';

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                        ),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: isAbone ? const Color(0xFFE8F0FF) : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(isAbone ? Icons.card_membership : Icons.directions_bus, color: isAbone ? const Color(0xFF3A7DFF) : const Color(0xFFFF6D00), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(lineName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            if (stationName.isNotEmpty) Text(stationName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ])),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isAbone ? const Color(0xFFE8F0FF) : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(isAbone ? 'Abone' : 'Biletë', style: TextStyle(color: isAbone ? const Color(0xFF3A7DFF) : const Color(0xFFFF6D00), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MAP TAB
// ─────────────────────────────────────────────
class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) => const MapScreen();
}

// ─────────────────────────────────────────────
// PROFILE TAB
// ─────────────────────────────────────────────
class _ProfileTab extends StatefulWidget {
  const _ProfileTab();
  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  String t(String sq, String en) => languageNotifier.value == 'sq' ? sq : en;

  Future<void> _setLanguage(String lang) async {
    languageNotifier.value = lang;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'language': lang});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
              builder: (context, snapshot) {
                String name = '';
                String surname = '';
                String email = user?.email ?? '';
                String gender = '';

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  name = data['name'] ?? '';
                  surname = data['surname'] ?? '';
                  email = data['email'] ?? email;
                  gender = data['gender'] ?? '';
                }

                return Column(
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.3), blurRadius: 20)],
                      ),
                      child: Center(
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('$name $surname', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 24),

                    // Profile info card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(children: [
                        _ProfileRow(icon: Icons.person_outline, label: t('Emri', 'Name'), value: '$name $surname'),
                        const Divider(height: 24),
                        _ProfileRow(icon: Icons.email_outlined, label: 'Email', value: email),
                        if (gender.isNotEmpty) ...[
                          const Divider(height: 24),
                          _ProfileRow(icon: Icons.people_outline, label: t('Gjinia', 'Gender'), value: gender),
                        ],
                        const Divider(height: 24),
                        _ProfileRow(icon: Icons.shield_outlined, label: t('Roli', 'Role'), value: t('Pasagjer', 'Passenger')),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // ✅ Language toggle card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.language, color: Color(0xFF3A7DFF), size: 20),
                          const SizedBox(width: 10),
                          Text(t('Gjuha', 'Language'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ]),
                        const SizedBox(height: 14),
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _setLanguage('sq'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: lang == 'sq' ? const Color(0xFF3A7DFF) : const Color(0xFFF8FAFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: lang == 'sq' ? const Color(0xFF3A7DFF) : Colors.grey.shade200),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Text('🇦🇱', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Text('Shqip', style: TextStyle(fontWeight: FontWeight.bold, color: lang == 'sq' ? Colors.white : Colors.grey.shade700)),
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _setLanguage('en'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: lang == 'en' ? const Color(0xFF3A7DFF) : const Color(0xFFF8FAFF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: lang == 'en' ? const Color(0xFF3A7DFF) : Colors.grey.shade200),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                                  const SizedBox(width: 8),
                                  Text('English', style: TextStyle(fontWeight: FontWeight.bold, color: lang == 'en' ? Colors.white : Colors.grey.shade700)),
                                ]),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await AuthService().logout();
                          if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyApp()));
                        },
                        style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: Icon(Icons.logout, color: Colors.red.shade400, size: 20),
                        label: Text(t('Dil nga llogaria', 'Sign out'), style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE WIDGETS (unchanged)
// ─────────────────────────────────────────────
class _AboneCard extends StatelessWidget {
  final String label;
  final String validUntil;
  final VoidCallback onShowQR;
  const _AboneCard({required this.label, required this.validUntil, required this.onShowQR});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3A7DFF), Color(0xFF1A3AFF)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF3A7DFF).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('URBANE', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
              child: const Text('Aktive ✓', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Skadon: $validUntil', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('🚌 Të gjitha linjat', style: TextStyle(color: Colors.white70, fontSize: 13)),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onShowQR,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.qr_code, color: Color(0xFF3A7DFF), size: 14),
                    SizedBox(width: 5),
                    Text('Shiko QR', style: TextStyle(color: Color(0xFF3A7DFF), fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _ApprovedForPaymentCard extends StatelessWidget {
  final String categoryLabel;
  final int price;
  final bool isPaying;
  final VoidCallback onPay;
  const _ApprovedForPaymentCard({required this.categoryLabel, required this.price, required this.isPaying, required this.onPay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('✅', style: TextStyle(fontSize: 34)),
          SizedBox(width: 12),
          Expanded(child: Text('Aplikimi u aprovua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        Text('Abone $categoryLabel është gati për pagesë.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: isPaying ? null : onPay,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: isPaying
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text('Paguaj $price Lekë', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _PendingAboneCard extends StatelessWidget {
  const _PendingAboneCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade200)),
      child: const Row(children: [
        Text('⏳', style: TextStyle(fontSize: 36)),
        SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Aplikimi në pritje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 4),
          Text('Dokumenti juaj është duke u verifikuar nga administratori.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ])),
      ]),
    );
  }
}

class _RejectedAboneCard extends StatelessWidget {
  const _RejectedAboneCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade200)),
      child: Column(children: [
        const Row(children: [
          Text('❌', style: TextStyle(fontSize: 36)),
          SizedBox(width: 16),
          Expanded(child: Text('Aplikimi u refuzua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 44,
          child: ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboneScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A7DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Apliko përsëri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _NoAboneCard extends StatelessWidget {
  final VoidCallback? onBuyAbone;
  const _NoAboneCard({required this.onBuyAbone});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3A7DFF).withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(children: [
        const Text('🚌', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        const Text('Nuk keni abone aktive', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Bli një abone mujore dhe udhëto pa limit!', style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: onBuyAbone,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A7DFF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Bli Abone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ProfileRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF3A7DFF), size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ])),
    ]);
  }
}